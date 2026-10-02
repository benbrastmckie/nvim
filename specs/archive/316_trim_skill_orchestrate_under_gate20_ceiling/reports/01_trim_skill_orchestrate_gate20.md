# Research Report: Task #316

**Task**: 316 - Trim `skills/skill-orchestrate/SKILL.md` back under its verify-deploy gate 20 per-file context ceiling
**Started**: 2026-10-02
**Completed**: 2026-10-02
**Effort**: standard
**Dependencies**: None
**Sources/Inputs**:
- Codebase: `agent-system/extensions/core/skills/skill-orchestrate/SKILL.md`,
  `agent-system/extensions/core/docs/architecture/orchestrate-state-machine.md`,
  `agent-system/extensions/core/docs/architecture/handoff-schema.md`,
  `agent-system/extensions/core/scripts/lint/lint-postflight-boundary.sh`,
  `.claude/scripts/verify-deploy.sh` (gate 20), `agent-system/extensions/core/scripts/tests/test-verify-deploy-context-budget.sh`
- Live gate run: `ORCHESTRATOR_BUDGET_GATE_MODE=hard bash .claude/scripts/verify-deploy.sh --only-gate 20`
**Artifacts**: this report (`specs/316_trim_skill_orchestrate_under_gate20_ceiling/reports/01_trim_skill_orchestrate_gate20.md`)
**Standards**: report-format.md, subagent-return.md, `.claude/rules/source-store-deploy-boundary.md`

## Executive Summary

- Verified the defect directly: gate 20 measures only the **source store** file
  (`agent-system/extensions/core/skills/skill-orchestrate/SKILL.md`) via `wc -c` against a
  20000 B ceiling in `agent-system/extensions/core/context/config/orchestrator-context-budget.json`.
  Live run confirms `[FAIL] skills/skill-orchestrate/SKILL.md (20930 B) exceeds its configured
  ceiling (20000 B)`; aggregate eager-load (65599/65950 B) and `commands/orchestrate.md`
  (19891/21000 B) both PASS — only this one file is over.
- **Decision: option (a), relocate-and-trim.** Two mechanically-identified duplicate-prose
  blocks in SKILL.md are already fully (or more fully) restated in
  `docs/architecture/orchestrate-state-machine.md` and `docs/architecture/handoff-schema.md`.
  Inverting canonicality for both — making the architecture docs the home of the full text and
  leaving SKILL.md a short pointer — removes **1075 B**, comfortably clearing the 930 B needed
  (verified by `wc -c` on drafted replacement text, not estimated).
- The dispatch's own ~690 B dedup-alone estimate (relocating only the `.status`/`.persisted_status`
  paragraph) is correct as far as it goes but insufficient alone, exactly as flagged — it leaves
  the file ~240 B over. A second relocation (the `## MUST NOT (Postflight Boundary)` section body)
  plus a smaller tightening of the `## MUST NOT (Context Flatness Constraint)` section close the
  gap with margin to spare.
- No contract content is deleted: both relocated blocks' full prose already exists, or is
  rewritten to exist in full, at the pointer target. `lint-postflight-boundary.sh` was read in
  full and confirmed to check only for the **heading text** `## MUST NOT (Postflight Boundary)`,
  not its body — shrinking the body under that heading is safe.

## Context & Scope

Task 316 (`task_type: meta`) is scoped to fixing one red gate (`verify-deploy.sh` gate 20, hard
mode) by trimming `agent-system/extensions/core/skills/skill-orchestrate/SKILL.md` from 20930 B
to at or under 20000 B, without discarding any contract content — specifically the
`.status`/`.persisted_status` distinction paragraph added by commit `f9cac3ae6`, which is
explicitly load-bearing (it is the contract that stops a reader mistaking an agent's
self-report for proof of a persisted state transition).

This research phase's job is to rule on the design question the dispatch poses — option (a)
(relocate-and-trim) vs. option (b) (re-derive the ceiling) — and, having chosen (a), to
mechanically identify enough duplicate-prose relocation targets to clear the 930 B gap with
verified arithmetic, not estimated arithmetic. Actually editing the files is implementation-phase
work; this report hands the plan/implement phases exact before/after text and verified byte
deltas so no further investigation is needed before applying the edits.

## Findings

### The measured defect (independently reproduced)

```
$ ORCHESTRATOR_BUDGET_GATE_MODE=hard bash .claude/scripts/verify-deploy.sh --only-gate 20
  [PASS] measure-eager-context.sh --check: no volatile-file hits
  [PASS] eager-load total (65599 B) within baseline (65950 B)
  [PASS] commands/orchestrate.md (19891 B) within ceiling (21000 B)
  [FAIL] skills/skill-orchestrate/SKILL.md (20930 B) exceeds its configured ceiling (20000 B)
```

`verify-deploy.sh`'s gate 20 (sub-check C, lines ~1053-1077) reads
`wc -c < "$TARGET/agent-system/extensions/core/$rel_path"` — **the source store only**, never
`.claude/`'s deployed mirror. This means the fix only has to land under
`agent-system/extensions/core/` (per `.claude/rules/source-store-deploy-boundary.md`) for the gate
itself to go green; keeping the deployed `.claude/skills/skill-orchestrate/SKILL.md` mirror in
sync is still required by the normal deploy/sync workflow, but is not what this gate checks.

### Why the dedup-alone estimate (~690 B) is insufficient, and what closes the gap

The dispatch's own arithmetic check (replacing the ~940 B `.status`/`.persisted_status` paragraph
with a ~250 B pointer, netting ~690 B) is directionally correct but — as the dispatch itself
warned — insufficient alone: 20930 − 690 ≈ 20240 B, still 240 B over. Two more candidates were
mechanically identified (grepped for near-duplicate prose against the four named docs, not
chosen by taste) and verified by drafting the actual replacement text and measuring it with
`wc -c`:

**1. `.status` vs. `.persisted_status` paragraph** (`SKILL.md:237-245`, the HARD CONSTRAINT
content) — already restated, less completely, in
`docs/architecture/orchestrate-state-machine.md:401-406` (the "Context Flatness Guarantee"
section), which currently defers to SKILL.md as canonical ("See `SKILL.md`'s 'Move 3: Postflight'
section for the full contract text this mirrors."). No other file in the repo references this
paragraph as canonical (`grep -rn "full contract text this mirrors"` across `docs/`, `context/`,
`scripts/`, `skills/` returns only these two sites), so inverting is a clean, unambiguous move:

| | Bytes |
|---|---|
| Current SKILL.md paragraph (9 lines) | 820 B |
| Replacement pointer (verified via `wc -c`, drafted below) | 392 B |
| **Savings** | **428 B** |

Replacement text for `SKILL.md:237-245`:
```
**`.status` vs. `.persisted_status`**: `.status` above is the dispatched agent's own
self-report (diagnostic only — never used for loop-control); `.persisted_status` is
`state.json`'s actual post-postflight status. They legitimately diverge by design (e.g. an
empty-blocker `partial`). Full contract: `docs/architecture/orchestrate-state-machine.md`'s
"Context Flatness Guarantee" section.
```

Corresponding change in `docs/architecture/orchestrate-state-machine.md` (lines 401-406): expand
that paragraph to carry the FULL nuance currently only in SKILL.md (the "self-report" framing,
the `$dispatch_status` vs. `$verdict`/`$halt`/`$infra_exempt_cycle` loop-control distinction, the
`status=partial` while `persisted_status` stays whatever-it-already-was example, and the closing
"documented behavior, not a defect" sentence), and replace its own closing sentence — which
currently defers to SKILL.md — with the inverse: state that this is now the full contract text
and that SKILL.md's Move 3 section carries only a pointer back here. Recommended replacement
paragraph for the doc:
```
**`.status` vs. `.persisted_status`** — the postflight JSON carries both, and they mean
different things. `.status` (`dispatch_status` above) is the dispatched agent's own
**self-report**, verbatim from its handoff or a recovered `.return-meta.json`; it is used ONLY
for `SKILL.md`'s Move 3 diagnostic echo — every loop-control decision there keys off
`$verdict`/`$halt`/`$infra_exempt_cycle`, never `$dispatch_status`. `.persisted_status`
(`persisted_status` above) is what `specs/state.json` actually says for this task after this
postflight ran, read fresh at emit time. The two legitimately differ by design — e.g. an
empty-blocker `partial` performs no transition, so `status=partial` while `persisted_status`
stays whatever it already was — and that divergence is documented behavior, not a defect. This
is the full contract text; `SKILL.md`'s Move 3 section carries only a short pointer back here.
```
(This addition to the doc is prose relocation, not new eager-loaded content — the doc is
on-demand reference material per the repo's own lazy-loading idiom, not part of the eager-load
budget gate 20 also checks.)

**2. `## MUST NOT (Postflight Boundary)` section body** (`SKILL.md:303-319`) — already more
fully and more precisely restated in `docs/architecture/handoff-schema.md:924-947`'s own
"Postflight Boundary" section, which SKILL.md's current text already points to via a "Full
accounting" sentence while *also* fully restating the same five prohibitions and the D4
exception underneath it. `handoff-schema.md:945` already states the intended end state
explicitly: *"there is no second, inline copy of this logic in `skill-orchestrate/SKILL.md` to
keep in sync."* The current SKILL.md body is exactly that unwanted inline copy. Verified via
`scripts/lint/lint-postflight-boundary.sh`'s `has_postflight_boundary_section()` (grep
`^## MUST NOT \(Postflight Boundary\)`) that only the **heading text** is mechanically enforced,
never the body — shrinking the body is safe.

| | Bytes |
|---|---|
| Current SKILL.md section body (heading + 16 lines) | 1124 B |
| Replacement pointer (verified via `wc -c`, drafted below) | 628 B |
| **Savings** | **496 B** |

Replacement text for `SKILL.md:303-319` (heading unchanged — required by the lint):
```
## MUST NOT (Postflight Boundary)

Full contract (the five prohibited operations, the D4 verbatim-recovery exception, and why
`orchestrate-cycle-postflight.sh` is this boundary's sole implementation): see
`docs/architecture/handoff-schema.md`'s "Postflight Boundary" section and
`context/standards/postflight-tool-restrictions.md`. After a dispatch returns (Move 3), this
skill only reads the handoff, drives the state transition, and cleans up temp/marker files.

Also: never hardcode a phase order (dispatch whatever phase `orchestrate-cycle-plan.sh` names);
the `detected_defects` constraint above (Move 4) applies here too.
```
No change needed in `handoff-schema.md` — it already carries the full, more detailed version;
this is a pure one-directional trim, not a relocation requiring a doc edit.

Keep the D4 inline rationale in **Move 3**'s own bash-comment block (`SKILL.md:199-202`,
unchanged) — it already explains D4 operationally where the code that triggers it lives; the
Postflight Boundary section's reference to "the D4 verbatim-recovery exception" by name is
sufficient there since the full rationale is one hop away in `handoff-schema.md`.

**3. `## MUST NOT (Context Flatness Constraint)` section** (`SKILL.md:293-301`) — minor
additional tightening, not a full relocation (this section was already pointer-heavy). The
871 B/cycle/task figure is cited in both SKILL.md and `orchestrate-state-machine.md`'s own
"Context Flatness Guarantee" section as a fact, not duplicated prose; the savings here come from
tighter wording, not content removal.

| | Bytes |
|---|---|
| Current section body (heading + 8 lines) | 645 B |
| Tightened version (verified via `wc -c`, drafted below) | 494 B |
| **Savings** | **151 B** |

Replacement text for `SKILL.md:293-301` (heading unchanged):
```
## MUST NOT (Context Flatness Constraint)

Never read `reports/*.md`, `plans/*.md`, `summaries/*.md`, or `handoffs/*.md` during the loop —
`orchestrate-cycle-postflight.sh` performs every sanctioned read on this skill's behalf (the
handoff, gated by mtime/`dispatch_seq`; the bounded recovery fallbacks). Full accounting and the
measured 871 B/cycle/task growth figure: `docs/architecture/orchestrate-cycle-postflight.md` and
`orchestrate-state-machine.md`'s `## Context Flatness Guarantee`.
```

### Combined arithmetic (verified, not estimated)

| Relocation | Savings |
|---|---|
| 1. `.status`/`.persisted_status` paragraph (HARD CONSTRAINT content — relocated, not deleted) | 428 B |
| 2. `## MUST NOT (Postflight Boundary)` section body | 496 B |
| 3. `## MUST NOT (Context Flatness Constraint)` section (tightening only) | 151 B |
| **Total** | **1075 B** |

**20930 B − 1075 B = 19855 B**, which is **145 B under** the 20000 B ceiling — enough margin to
absorb the implement phase's own minor wording drift from these drafts (e.g. if the exact prose
chosen differs by a word or two from what is quoted above) without re-breaching. Relocations 1
and 2 alone (924 B) leave the file at 20006 B — 6 B over — which is why relocation 3 is included
rather than treated as optional polish; it is necessary margin, not cosmetic.

### No contract content is lost

- The `.status`/`.persisted_status` paragraph's full prose is **relocated**, not deleted: it
  will exist in full (and slightly more completely — the self-report/loop-control framing is
  made more explicit) at `docs/architecture/orchestrate-state-machine.md`'s "Context Flatness
  Guarantee" section, with SKILL.md carrying a pointer that preserves the same practical
  takeaway (which field is diagnostic-only, which is the persisted truth, and that they
  legitimately diverge).
- The Postflight Boundary section's five prohibitions and D4 exception already exist, in more
  detail, at `handoff-schema.md`'s "Postflight Boundary" section (verified by reading it in
  full: `docs/architecture/handoff-schema.md:924-947`). Nothing in SKILL.md's current body adds
  information absent from that doc.
- The Context Flatness tightening removes no fact (the 871 B figure, the `reports/*.md` etc. read
  prohibition, and the `orchestrate-cycle-postflight.sh` pointer are all retained) — only wording
  is tightened.

### Why option (b) (re-derive the ceiling) was rejected

Option (b) requires a positive argument for why 20000 B is wrong for this file and what new
mechanism would prevent unbounded re-growth once the per-file ceiling is raised. No such argument
holds here: the file has already been trimmed once before (commit `8b7d5020d`) and re-breached by
exactly one subsequent contract addition (`f9cac3ae6`, ~940 B) — the per-file ceiling is doing
its job of catching exactly the growth pattern it exists to catch (eager-loaded contract prose
that duplicates on-demand reference material). The aggregate budget being comfortably under
baseline (65599/65950 B) is irrelevant to the per-file ceiling's purpose, which the dispatch
itself notes is "to force contract prose out of eager-loaded context and into on-demand docs" —
precisely what relocations 1-3 above do. Raising the ceiling here would reward the chronic
pattern (restating already-documented contract prose inline) rather than fix it, and this task's
own research turned up two more mechanically-identifiable instances of exactly that pattern
beyond the one the dispatch already flagged — evidence the ceiling is working as intended, not
evidence it is miscalibrated.

## Decisions

- **Decision**: Pursue option (a), relocate-and-trim. Rejected option (b) (re-derive the
  ceiling) for the reasons above — no positive argument for raising it, and clear evidence the
  ceiling is correctly catching chronic duplicate-prose growth.
- **Decision**: All three relocations/tightenings above (totaling 1075 B) are needed, not just
  the dispatch's originally-flagged `.status`/`.persisted_status` one (428 B) and the Postflight
  Boundary one (496 B) — those two alone (924 B) leave the file 6 B over the ceiling. Relocation
  3 (Context Flatness Constraint tightening, 151 B) is load-bearing margin, not optional polish.
- **Decision**: No edit to `context/standards/postflight-tool-restrictions.md` is needed — it is
  already a pointer target, not a duplication source, for either relocation.
- **Decision**: All edits land under `agent-system/extensions/core/` only (source store), per
  `.claude/rules/source-store-deploy-boundary.md`; gate 20 itself reads only the source store
  copy via `wc -c`, confirmed by reading `verify-deploy.sh`'s gate 20 implementation directly.
  The deployed `.claude/` mirror should still be kept in sync via the normal deploy/sync
  workflow, but is not what this gate's pass/fail depends on.

## Recommendations

1. **Plan phase**: produce a plan with three edit steps against
   `agent-system/extensions/core/skills/skill-orchestrate/SKILL.md` (replace the two sections and
   one paragraph with the drafted pointer text above) and one edit step against
   `agent-system/extensions/core/docs/architecture/orchestrate-state-machine.md` (expand the
   `.status`/`.persisted_status` paragraph at its "Context Flatness Guarantee" section to be the
   full canonical text, removing its "mirrors SKILL.md" framing).
2. **Implement phase — verification close-out** (per the dispatch's "CLOSE BY" instructions,
   which apply once edits are applied in the implement phase, not in this research phase):
   - Re-run `ORCHESTRATOR_BUDGET_GATE_MODE=hard bash .claude/scripts/verify-deploy.sh --only-gate 20`
     (or the full `verify-deploy.sh`) and confirm `skills/skill-orchestrate/SKILL.md` now reports
     `within ceiling`.
   - Run `bash agent-system/extensions/core/scripts/tests/test-verify-deploy-context-budget.sh`
     and confirm it still passes — its own baseline check already expects
     `skills/skill-orchestrate/SKILL.md` to be at or under ceiling (comment at the top of that
     test file), so this trim moves the real file further into conformance with that expectation,
     not away from it.
   - Confirm every sentence removed from SKILL.md is locatable, in equivalent or greater force,
     at the pointer target: `docs/architecture/orchestrate-state-machine.md`'s "Context Flatness
     Guarantee" section (relocation 1) and `docs/architecture/handoff-schema.md`'s "Postflight
     Boundary" section (relocation 2, already present — no edit needed there).
   - Also sync the deployed `.claude/` mirror of both edited source-store files via the normal
     deploy workflow, even though gate 20 itself does not require this for its own pass/fail.
3. Because this file is under chronic budget pressure (two trims in its recent history, both
   re-breached by the next contract addition), flag for the plan/implement phase (and for a
   possible follow-up task, not in this task's scope) that the next contract addition to
   SKILL.md should default to a pointer into an architecture doc rather than inline prose, given
   the ~145 B margin this trim leaves is not large.

## Risks & Mitigations

- **Risk**: implement-phase wording drifts slightly from the drafted replacement text above,
  eroding the 145 B margin. **Mitigation**: the drafts above were measured with `wc -c` and are
  ready to use verbatim; if the implement phase does deviate, it should re-run `wc -c` on the
  edited file before closing out, not assume the arithmetic still holds.
- **Risk**: a sibling task concurrently touches `commands/orchestrate.md` or
  `orchestrator-context-budget.json` during the same orchestrate cycle (the dispatch's Territory
  block lists tasks 268/320/321 as concurrent siblings, none of which touch these paths).
  **Mitigation**: re-read `SKILL.md` immediately before editing in the implement phase per the
  Territory contract, in case a sibling has already changed it.
- **Risk**: the doc edit to `orchestrate-state-machine.md` could itself grow that file past some
  limit. **Mitigation**: that doc is on-demand reference material, not part of the eager-load
  budget gate 20 enforces (confirmed: gate 20's per-file ceilings list is
  `commands/orchestrate.md` and `skills/skill-orchestrate/SKILL.md` only, read from
  `orchestrator-context-budget.json`'s `.files` keys) — no ceiling applies to it.

## Context Extension Recommendations

- **Topic**: chronic per-file budget pressure on `skill-orchestrate/SKILL.md`.
- **Gap**: there is no standing guidance telling a future contract-adding change to default to a
  pointer-into-architecture-doc pattern rather than inline prose for this specific file, despite
  two trim-then-re-breach cycles in its history (`8b7d5020d` then `f9cac3ae6`, and now this task).
- **Recommendation**: consider a short note in
  `docs/architecture/orchestrate-state-machine.md` or `context/standards/` (not in scope for this
  task to create) stating that new SKILL.md contract prose should default to architecture-doc
  placement with a pointer, given the file's narrow remaining margin. Left as a recommendation
  only, not a new task per this agent's instructions (context gaps are documented, not spawned
  into tasks).

## Appendix

- Live gate run: `ORCHESTRATOR_BUDGET_GATE_MODE=hard bash .claude/scripts/verify-deploy.sh --only-gate 20`
- Byte counts verified via `wc -c` on the real file and on drafted replacement text in the
  session scratchpad (not the task directory).
- `grep -rn "full contract text this mirrors"` across `docs/`, `context/`, `scripts/`,
  `skills/` (confirms only one inversion target for the `.status`/`.persisted_status` paragraph).
- `grep -rln "Context Flatness Constraint"` across `scripts/` (confirms no lint depends on that
  heading's exact text, unlike the Postflight Boundary heading).
- Read in full: `scripts/lint/lint-postflight-boundary.sh`,
  `docs/architecture/handoff-schema.md` lines 924-991,
  `docs/architecture/orchestrate-state-machine.md` lines 1-21 and 380-429 and 597-694,
  `agent-system/extensions/core/skills/skill-orchestrate/SKILL.md` (full file, 333 lines),
  `agent-system/extensions/core/scripts/tests/test-verify-deploy-context-budget.sh` (header
  comment and fixture-baseline section).
