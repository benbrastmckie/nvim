# Implementation Plan: Task #316

- **Task**: 316 - Trim `skills/skill-orchestrate/SKILL.md` back under its verify-deploy gate 20 per-file context ceiling
- **Status**: [NOT STARTED]
- **Effort**: 1.5 hours
- **Dependencies**: None
- **Research Inputs**: specs/316_trim_skill_orchestrate_under_gate20_ceiling/reports/01_trim_skill_orchestrate_gate20.md
- **Artifacts**: plans/01_trim-skill-orchestrate-gate20.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

`verify-deploy.sh` gate 20 is RED: `agent-system/extensions/core/skills/skill-orchestrate/SKILL.md`
measures 20930 B against a 20000 B per-file ceiling, so at least 930 B must leave the file
without any contract statement leaving the system. Research ruled on the dispatch's design
question in favour of option (a), relocate-and-trim, and mechanically identified three
duplicate-prose sites whose drafted replacements were measured with `wc -c` rather than
estimated: a canonicality inversion of the `.status`/`.persisted_status` contract into
`docs/architecture/orchestrate-state-machine.md` (428 B), a collapse of the
`## MUST NOT (Postflight Boundary)` body to a pointer into the already-fuller
`docs/architecture/handoff-schema.md` (496 B), and a wording tightening of
`## MUST NOT (Context Flatness Constraint)` (151 B). The plan applies those three edits in
byte-accounted order, then closes out against the full gate set.

### Research Integration

The research report supplies verbatim, `wc -c`-measured replacement text for all three sites and
the expanded canonical paragraph for the architecture doc, so no further investigation is needed
before editing. Three findings shape the phasing directly:

- The combined saving is 1075 B, landing the file at 19855 B — 145 B of margin. Relocations 1+2
  alone (924 B) leave it at 20006 B, i.e. **6 B over**, so relocation 3 is load-bearing margin,
  not optional polish. Each phase therefore re-measures with `wc -c` rather than trusting the
  drafted arithmetic.
- Gate 20 reads the **source store** copy only (`wc -c` on
  `agent-system/extensions/core/$rel_path`), never `.claude/`'s mirror — so the gate greens on a
  source-store-only edit, and the mirror sync is a separate deploy-workflow obligation rather
  than a gate dependency.
- `scripts/lint/lint-postflight-boundary.sh` enforces only the **heading text**
  `## MUST NOT (Postflight Boundary)`, never its body. Shrinking that body is safe provided the
  heading survives byte-identical.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No roadmap context was provided for this dispatch.

## Goals & Non-Goals

**Goals**:
- Bring `agent-system/extensions/core/skills/skill-orchestrate/SKILL.md` to at or under 20000 B,
  turning `verify-deploy.sh` gate 20 green in `ORCHESTRATOR_BUDGET_GATE_MODE=hard`.
- Preserve every contract statement in equivalent or greater force at the path SKILL.md now
  points to — in particular the `.status` vs `.persisted_status` paragraph, which the dispatch
  names as load-bearing and forbids weakening.
- Invert the `.status`/`.persisted_status` canonicality so the architecture doc is the home of
  the full text and SKILL.md carries the pointer, matching the repo's stated lazy-context-loading
  idiom for SKILL.md.
- Keep `scripts/tests/test-verify-deploy-context-budget.sh` passing.

**Non-Goals**:
- Raising the 20000 B ceiling (option (b)) — explicitly rejected by research, which found the
  ceiling catching exactly the growth pattern it exists to catch.
- Editing `context/standards/postflight-tool-restrictions.md` or
  `docs/architecture/handoff-schema.md` — both are already pointer targets carrying the full
  text, not duplication sources.
- Adding the standing "default to a pointer, not inline prose" guidance note that research
  recommended for this file's chronic budget pressure; that is a follow-up, out of scope here.
- Touching `commands/orchestrate.md` or `orchestrator-context-budget.json` — both already PASS
  and neither is the binding constraint.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Implement-phase wording drifts from the measured drafts, eroding the 145 B margin | H | M | Use the report's drafted text verbatim; re-run `wc -c` after every phase and treat the number, not the draft arithmetic, as the verdict |
| A sibling task in this same cycle has already modified SKILL.md | M | L | Re-read SKILL.md immediately before each edit per the Territory contract; tasks 320/321's declared `file_scope` does not include it, so a foreign modification is a STOP-and-report signal |
| The Postflight Boundary heading is altered while trimming its body, silently breaking `lint-postflight-boundary.sh` | H | L | Replace only the lines *below* the heading; re-run the lint explicitly in Phase 3 |
| A pointer is written to a section heading that does not exist, producing a dangling reference a `prose`-tier diff read would miss | M | M | Phase-level verification greps the target file for each cited heading string before the phase closes |
| Another file still treats SKILL.md as canonical for the relocated paragraph | M | L | Research's `grep -rn "full contract text this mirrors"` found only the two sites; re-run that grep plus a `persisted_status` sweep in Phase 1 |
| Deployed `.claude/` mirror left stale, so the next `/orchestrate` cycle reads the old SKILL.md | M | M | Phase 3 syncs the mirror via the normal deploy workflow and re-measures both copies |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2 | 1 |
| 3 | 3 | 2 |

Phases within the same wave can execute in parallel. All three phases here are strictly
sequential: Phases 1 and 2 both edit the same file and the byte accounting is cumulative, and
Phase 3 can only judge the gate once both trims have landed.

### Phase 1: Invert `.status`/`.persisted_status` Canonicality [NOT STARTED]

**Goal**: Move the full `.status` vs `.persisted_status` contract text into
`docs/architecture/orchestrate-state-machine.md`'s "Context Flatness Guarantee" section as the
canonical home, and leave SKILL.md's Move 3 section a short pointer — removing ~428 B from
SKILL.md while strengthening, not weakening, the contract.

**Tasks**:
- [ ] Re-read both target files immediately before editing (Territory contract: a sibling may
      have changed them); record SKILL.md's starting `wc -c` as the baseline for this phase
- [ ] In `docs/architecture/orchestrate-state-machine.md`, replace the condensed
      `.status` (`dispatch_status`) paragraph that currently closes with "See `SKILL.md`'s
      \"Move 3: Postflight\" section for the full contract text this mirrors." with the report's
      recommended full canonical paragraph — carrying the self-report framing, the
      `$verdict`/`$halt`/`$infra_exempt_cycle` loop-control distinction, the empty-blocker
      `partial` example, the "documented behavior, not a defect" closer, and the inverted closing
      sentence stating that this is the full text and SKILL.md carries only a pointer back
- [ ] In `skills/skill-orchestrate/SKILL.md`, replace the 9-line
      `**`.status` vs. `.persisted_status`**` paragraph in Move 3 with the report's drafted
      392 B pointer version, citing
      `docs/architecture/orchestrate-state-machine.md`'s "Context Flatness Guarantee" section
- [ ] Confirm the cited heading exists verbatim in the target doc
- [ ] Re-run `grep -rn "full contract text this mirrors"` and a `persisted_status` sweep across
      `docs/`, `context/`, `scripts/`, `skills/` to confirm no other file still defers to
      SKILL.md as canonical for this paragraph
- [ ] Measure `wc -c` on SKILL.md and record the actual delta against the 428 B hypothesis
- [ ] Commit this green sub-step with scoped staging (these two files only, explicit paths)

**Timing**: 0.5 hours

**Depends on**: none

**Verification Tier**: interface

**Scope Hypothesis**: This phase is hypothesised to remove 428 B from SKILL.md (820 B paragraph
-> 392 B pointer), touching exactly 2 files, and the relocated contract is hypothesised to have
exactly one other referring site (the architecture doc itself). Confirm all three at
implementation time: `wc -c` before/after on SKILL.md, `git status --short` for the file count,
and the two greps above for the referrer count. If the measured delta is materially below 428 B,
carry the shortfall forward into Phase 2's margin check rather than declaring the phase done.

**Files to modify**:
- `agent-system/extensions/core/docs/architecture/orchestrate-state-machine.md` - expand the
  `.status`/`.persisted_status` paragraph into the full canonical contract text; invert its
  closing cross-reference so it no longer defers to SKILL.md
- `agent-system/extensions/core/skills/skill-orchestrate/SKILL.md` - replace the 9-line Move 3
  contract paragraph with the drafted pointer

**Verification**:
- `wc -c` on SKILL.md shows a reduction, recorded as an actual number (hypothesis: 428 B)
- The pointer's cited heading (`## Context Flatness Guarantee`) is present verbatim in
  `orchestrate-state-machine.md`
- Every clause of the removed paragraph (self-report framing, loop-control distinction, the
  empty-blocker `partial` divergence example, "documented behavior, not a defect") is locatable
  in the doc's new paragraph — checked clause by clause, not by overall impression
- No remaining file defers to SKILL.md as canonical for this contract
- Diff read-through confirms both changed hunks lie wholly inside prose, with no edit crossing
  into the surrounding bash fence in either file

---

### Phase 2: Collapse the Two `MUST NOT` Section Bodies to Pointers [NOT STARTED]

**Goal**: Remove the redundant inline copy of the Postflight Boundary contract (~496 B) and
tighten the Context Flatness Constraint wording (~151 B), bringing SKILL.md under 20000 B with
margin.

**Tasks**:
- [ ] Re-read SKILL.md immediately before editing; record its post-Phase-1 `wc -c`
- [ ] Replace the body beneath `## MUST NOT (Postflight Boundary)` with the report's drafted
      628 B pointer text, leaving the heading line byte-identical (a `lint-postflight-boundary.sh`
      dependency) and retaining the "never hardcode a phase order" / `detected_defects` sentence
- [ ] Verify the D4 operational rationale still stands in Move 3's own bash-comment block
      (untouched by this phase), since the new pointer text names the D4 exception without
      restating it
- [ ] Replace the body beneath `## MUST NOT (Context Flatness Constraint)` with the report's
      drafted 494 B tightened version, retaining the `reports/*.md`/`plans/*.md`/`summaries/*.md`/
      `handoffs/*.md` read prohibition, the `orchestrate-cycle-postflight.sh` attribution, and
      the measured 871 B/cycle/task figure
- [ ] Confirm both pointer targets' cited headings exist verbatim
      (`handoff-schema.md`'s "Postflight Boundary";
      `orchestrate-state-machine.md`'s `## Context Flatness Guarantee`;
      `orchestrate-cycle-postflight.md`)
- [ ] Measure `wc -c` on SKILL.md; confirm it is at or under 20000 B and record the remaining
      margin
- [ ] Commit this green sub-step with scoped staging (SKILL.md only)

**Timing**: 0.5 hours

**Depends on**: 1

**Verification Tier**: local

**Scope Hypothesis**: This phase is hypothesised to remove 647 B (496 B + 151 B) from SKILL.md,
touching exactly 1 file, landing the file at 19855 B with 145 B of margin. Confirm by `wc -c`
after each of the two replacements separately, not only at the end — if the combined post-phase
figure exceeds 20000 B, the phase is not complete and further already-duplicated prose must be
converted to pointers (do not stop at the drafted three sites and declare the gate someone
else's problem).

**Files to modify**:
- `agent-system/extensions/core/skills/skill-orchestrate/SKILL.md` - replace the
  `## MUST NOT (Postflight Boundary)` body with a pointer; tighten the
  `## MUST NOT (Context Flatness Constraint)` body

**Verification**:
- `grep -c '^## MUST NOT (Postflight Boundary)$'` on SKILL.md returns 1 (heading intact
  byte-for-byte)
- `bash agent-system/extensions/core/scripts/lint/lint-postflight-boundary.sh` passes
- `wc -c` on SKILL.md is <= 20000 B, with the exact figure and remaining margin recorded
- All five prohibited postflight operations and the D4 exception are locatable at
  `handoff-schema.md`'s "Postflight Boundary" section — enumerated and checked individually
- The 871 B figure and the artifact-read prohibition survive in the tightened Context Flatness
  text
- Diff read-through confirms every changed hunk lies inside prose regions only

---

### Phase 3: Gate Close-Out and Deploy Mirror Sync [NOT STARTED]

**Goal**: Confirm gate 20 PASSES with the trimmed file, the context-budget test still passes, no
contract statement was lost, and the deployed `.claude/` mirror matches the source store.

**Tasks**:
- [ ] Run `ORCHESTRATOR_BUDGET_GATE_MODE=hard bash .claude/scripts/verify-deploy.sh --only-gate 20`
      and confirm `skills/skill-orchestrate/SKILL.md` reports `within ceiling`
- [ ] Run the full `bash .claude/scripts/verify-deploy.sh` and confirm no gate regressed —
      distinguishing any pre-existing unrelated failure from one this task introduced, and
      recording that distinction explicitly
- [ ] Run `bash agent-system/extensions/core/scripts/tests/test-verify-deploy-context-budget.sh`
      and confirm it passes
- [ ] Sync the deployed mirror of both edited files via the normal deploy workflow; confirm
      `wc -c` agrees between `agent-system/extensions/core/skills/skill-orchestrate/SKILL.md` and
      `.claude/skills/skill-orchestrate/SKILL.md`
- [ ] Produce the no-content-lost audit: for every sentence removed from SKILL.md across Phases 1
      and 2, name the file and section where it now lives, in equivalent or greater force
- [ ] Re-run `ORCHESTRATOR_BUDGET_GATE_MODE=hard ... --only-gate 20` once more after the mirror
      sync, to confirm the sync did not perturb the measured file
- [ ] Commit the close-out with scoped staging

**Timing**: 0.5 hours

**Depends on**: 2

**Verification Tier**: full

**Commit Mode**: per-substep

**Files to modify**:
- `.claude/skills/skill-orchestrate/SKILL.md` - deploy-mirror sync only, written by the deploy
  workflow and never hand-authored (per `.claude/rules/source-store-deploy-boundary.md`)
- `.claude/docs/architecture/orchestrate-state-machine.md` - deploy-mirror sync only, same
  constraint

**Verification**:
- Gate 20 reports PASS for `skills/skill-orchestrate/SKILL.md` in hard mode
- Full `verify-deploy.sh` shows no gate newly failing relative to the pre-task baseline
- `test-verify-deploy-context-budget.sh` passes
- Source store and deployed mirror byte counts agree for both edited files
- The no-content-lost audit covers every removed sentence with a named destination

---

## Testing & Validation

- [ ] `ORCHESTRATOR_BUDGET_GATE_MODE=hard bash .claude/scripts/verify-deploy.sh --only-gate 20` —
      gate 20 PASSES, SKILL.md within its 20000 B ceiling
- [ ] `bash .claude/scripts/verify-deploy.sh` — no gate regressed
- [ ] `bash agent-system/extensions/core/scripts/tests/test-verify-deploy-context-budget.sh` — passes
- [ ] `bash agent-system/extensions/core/scripts/lint/lint-postflight-boundary.sh` — passes
      (heading preserved)
- [ ] Every sentence removed from SKILL.md is locatable, in equivalent force, at the path
      SKILL.md now points to
- [ ] Every pointer added to SKILL.md cites a heading that exists verbatim in its target file
- [ ] No edit landed under `.claude/**` by hand; only the deploy workflow wrote there

## Artifacts & Outputs

- `agent-system/extensions/core/skills/skill-orchestrate/SKILL.md` at or under 20000 B
- `agent-system/extensions/core/docs/architecture/orchestrate-state-machine.md` carrying the
  canonical `.status`/`.persisted_status` contract text
- Synced deploy mirrors of both files under `.claude/`
- Green gate 20 and a passing `test-verify-deploy-context-budget.sh`
- Execution summary at `specs/316_trim_skill_orchestrate_under_gate20_ceiling/summaries/01_*-summary.md`
  recording the measured before/after byte counts and the no-content-lost audit

## Rollback/Contingency

Both edited files are markdown under version control and each phase commits separately, so
reverting is a per-phase `git revert` of that phase's commit — no snapshot or destructive git
operation is needed, and none should be used (a sibling task is live in this same working tree
this cycle).

If Phase 2's measurement lands SKILL.md above 20000 B even after all three drafted edits, do NOT
raise the ceiling as a workaround — research rejected that posture with a positive argument.
Instead continue converting already-duplicated prose into pointers, identified mechanically by
grepping SKILL.md's prose against `docs/architecture/orchestrate-state-machine.md`,
`docs/architecture/handoff-schema.md`, `docs/architecture/orchestrate-cycle-postflight.md`, and
`context/standards/postflight-tool-restrictions.md`. If no further duplicate prose exists and the
file is still over, that is a genuine blocker: stop, report the measured shortfall, and surface
the ceiling-re-derivation question rather than deleting non-duplicated contract content.
