# Research Report: Task #368

- **Task**: 368 - Tier-selection discipline: make a non-final-phase `full` verification tier justify itself
- **Started**: 2026-10-08T08:58:23Z
- **Completed**: 2026-10-08T09:04:08Z
- **Effort**: ~1 hour (research only)
- **Dependencies**: Gate 8 suite-selection mechanism (COMPLETED — see Findings)
- **Sources/Inputs**: Codebase (`agent-system/extensions/core/**`), archived plan artifact, ROADMAP
- **Artifacts**: specs/368_tier_selection_discipline_non_final_full/reports/01_tier-selection-discipline.md
- **Standards**: report-format.md, subagent-return.md

## Executive Summary

- All anchors named in the dispatch are verified byte-exact: `context/formats/plan-format.md`
  lines 258/265-269/271/273-277/279-282; `agents/planner-agent.md` lines 216-227/310-311/384-389;
  `context/workflows/task-breakdown.md` lines 76-78/94/131; `context/contracts/phase-closure.md`
  lines 53/167-169. The defect is exactly as described: the only selection guidance a planner gets
  is "when uncertain, apply the strictest applicable tier," with no cost signal and no requirement
  to justify a `full` choice, and it is repeated nearly verbatim in two files (`plan-format.md`:271
  and `planner-agent.md`:220) with no qualification for phase position.
- The dependency is satisfied: task 366 (now archived under `specs/366_suite_level_selection_within_gate_8/`,
  state.json status `completed`) landed `run-all.sh --only SUITE[,SUITE,...]` and a sourced-only
  mapping library (`scripts/lib/suite-selection-lib.sh`, functions `suite_selection_select` /
  `suite_selection_unmapped` / `suite_selection_classify` / `suite_selection_select_annotated`).
  A cheaper non-final tier now has a concrete mechanism to cite.
- The live instance replays exactly as the dispatch states. Task 361's archived plan
  (`specs/archive/361_reclassify_bare_git_stash_as_destructive/plans/01_reclassify-stash-destructive.md`)
  declares `**Verification Tier**: full` at Phase 4, whose own Verification section already lists
  `bash agent-system/extensions/core/scripts/tests/test-guard-destructive-git.sh` as the first,
  targeted check, and separately requires the full `verify-deploy.sh` run with the phase's own text
  conceding "drift findings... for the files this phase edits are expected until Phase 6." Phase 6
  (the true final phase) also declares `full`, under `timeout 3000`, as required.
- No fifth surface duplicates the tie-break rule itself. A broader grep across
  `agent-system/extensions/` for `"strictest applicable tier"` / `"Verification Tier"` turns up
  eight more files that *mention* tiers, but every one of them defers by reference to
  `plan-format.md`'s `## Verification Tiers` section rather than restating the rule — including
  `rules/plan-format-enforcement.md`, `context/contracts/pre-edit-gate.md`,
  `context/contracts/reference-grounding.md`, `context/standards/git-workflow-narrative.md`,
  `docs/guides/user-guide.md`, `docs/architecture/batch-admit-schema.md`, and
  `context/patterns/batch-orchestration-guardrails.md`. The four files named in scope are the sole
  locus of the rule text; this confirms acceptance item 5 is achievable by editing exactly those
  four files, with one soft caveat noted below (see Risks & Mitigations).
- `agents/reviser-agent.md` is confirmed to carry zero independent tier guidance (zero matches for
  "Verification Tier" or "tier" in that file) and defers wholly to `plan-format.md` structure at
  lines 16, 93, and 177 as the dispatch states. The scope exclusion is correct; no follow-up gap
  was found in the revise path.
- `scripts/validate-artifact.sh` currently checks only presence and vocabulary-membership of
  `**Verification Tier**` (warn-only, lines 297-324) — it has no concept of phase finality and no
  justification-field check today. This means `agents/planner-agent.md`'s authoring checklist
  (lines 384-389) really is the only mechanical enforcement point available without adding new
  validator code, matching the dispatch's framing exactly.
- One gap not named in the dispatch: **no file in the plan format defines how "the final phase"
  is identified.** `plan-format.md`'s invariant and `planner-agent.md`'s MUST NOT both say "the
  final phase" as if the term were already operational, but there is no stated rule (last phase
  number? terminal node with no dependents in the wave graph? an explicit marker?). This must be
  settled by the plan, because the new justification requirement is phase-position-conditional and
  cannot be checked without an unambiguous definition of "final." See Recommendations.

## Context & Scope

This is a research-only dispatch for a four-file, source-store-only guidance change (no code, no
tests) described fully in the dispatch (`.dispatch/15.md`), whose description text is reproduced
in `state.json`'s `description` field for task 368 verbatim. The task is the "guidance" half of a
three-task batch (the other members being the mechanism task, 366, already complete, and a third
task not covered here). Scope is strictly the four files in `file_scope`:

1. `agent-system/extensions/core/context/formats/plan-format.md`
2. `agent-system/extensions/core/agents/planner-agent.md`
3. `agent-system/extensions/core/context/workflows/task-breakdown.md`
4. `agent-system/extensions/core/context/contracts/phase-closure.md`

`agents/reviser-agent.md` is explicitly excluded by the dispatch (verified correct below).
Research verified every anchor cited in the dispatch description against the actual file content,
confirmed the dependency task's deliverable, replayed the cited live instance against the archived
plan, and surveyed the broader corpus for any additional surface carrying independent tier
selection guidance that the four-file scope might miss.

## Findings

### Codebase Patterns

**The four named surfaces, verified line-for-line:**

- `plan-format.md:258` — `prose < local < interface < full` ordering.
- `plan-format.md:265-269` — the per-tier table; the `full` row is exactly line 269 ("Nothing is
  deferred past this tier. This is the ceiling").
- `plan-format.md:271` — `**Tie-break rule**: When uncertain, apply the strictest applicable tier
  (full > interface > local > prose).` This is the ONE line this task must qualify.
- `plan-format.md:273-277` — the non-negotiable invariant: tiering is GRANULARITY ONLY, "the full
  gate set still runs before a phase closes and before a task completes, unchanged," and "a
  tiering scheme that weakens the final gate is wrong, not a trade-off." This text must survive
  verbatim in force.
- `plan-format.md:279-282` — "A phase declaring `full` names `bash .claude/scripts/verify-deploy.sh`
  ... in its own verification criteria." No change needed here; it already describes the final-gate
  obligation correctly and is untouched by this task's scope.
- `planner-agent.md:216-227` (Step 8, "Assign a Verification Tier per Phase") — restates the
  strictest-when-uncertain bias at line 220 verbatim, and already carries the
  do-not-weaken-the-final-gate `**MUST NOT**` at line 227. This is where tier assignment actually
  happens during plan authoring.
- `planner-agent.md:310-311` — the phase template's bare `**Verification Tier**: {one of ...}`
  field, with no justification slot.
- `planner-agent.md:384-389` — the authoring checklist, explicitly self-described as "where
  authoring-time enforcement of the tier vocabulary actually lives; the validator's own check is
  advisory-only." Confirmed against `validate-artifact.sh`: the per-phase tier check (lines
  297-324) is warn-only in default mode and has no finality or justification logic — so this
  checklist genuinely is the sole mechanical gate available today.
- `task-breakdown.md:76-78` (Phase 1 template) and `:94` (Phase 2 template) — both show a bare
  `**Verification Tier:** {one of ...}` placeholder with no justification example.
- `task-breakdown.md:131` — the worked "interface" example; `:154` and `:171` carry additional
  worked examples (`local`, `full`) not named in the dispatch but relevant: `:171`'s `full` example
  already gives a one-line rationale in parentheses ("touches shared token generation, email
  delivery, and auth state"), which is a usable template for what a required justification line
  should look like in practice.
- `phase-closure.md:53` — "the one with the smallest remaining work — fewer steps, a lower
  `**Verification Tier**`" as part of the cheapest-closure-first ordering. A cheaper non-final tier
  must be presented here as a first-class way to close a phase legitimately, not as a shortcut an
  implementer should second-guess.
- `phase-closure.md:167-169` — the no-promotion-without-evidence rule: a phase's declared
  verification must be "run in this dispatch and observed green," "never trusted on sight." This is
  the cost multiplier named in the dispatch: a `full` declaration is a real, mandatory gate run per
  phase per dispatch, not a formality satisfiable by citing a past run.

**Dependency (task 366) deliverable, confirmed landed:**

`specs/366_suite_level_selection_within_gate_8/` (state.json `project_number: 366`, `status:
completed`) added, per its summary at
`specs/366_suite_level_selection_within_gate_8/summaries/01_run-all-suite-selection-summary.md`:
- `run-all.sh --only SUITE[,SUITE,...]` — strictly opt-in, validates every token before running
  anything, filters at one site before `TOTAL_DISCOVERED` so every downstream mechanism
  (`--jobs`, `known-failures.txt`, `--timings`) inherits the narrowing.
- `scripts/lib/suite-selection-lib.sh` — maps a touched source-store path to the suite(s) that
  cover it (three-strata: basename pairing, grep-based reference lookup, a `__FULL_SWEEP__`
  fail-safe sentinel on zero hits), exposed as `suite_selection_select`.
- Explicit honesty constraint carried in `context/standards/shell-script-testing.md:178-183`:
  "a selected-subset pass is NOT evidence that doc-sync pins hold — the same already-accepted
  trade-off this doc already records for `--skip-slow`." `Gate 8's own invocation
  (verify-deploy.sh) keeps running the full, unselected sweep unchanged` — selection is additive,
  the ceiling gate itself is untouched.

This means a non-final phase choosing `local` or `interface` tier at Gate-8 granularity now has a
concrete command to name: `bash agent-system/extensions/core/scripts/tests/run-all.sh --only
<mapped-suite-name>`, resolved via `suite_selection_select` against the phase's touched files.

**Live instance replay (task 361, archived):**

`specs/archive/361_reclassify_bare_git_stash_as_destructive/plans/01_reclassify-stash-destructive.md`
confirms the dispatch's description exactly:
- Phase 4 ("Guard Detector, New Action Class, and Refusal Message") declares `**Verification
  Tier**: full` (line 426). Its own Verification section (lines 439-450) lists, in order: (1)
  `bash agent-system/extensions/core/scripts/tests/test-guard-destructive-git.sh` fully green,
  tally compared to the Phase 3 red baseline; (2) `bash .claude/scripts/verify-deploy.sh`, with the
  phase's own text conceding "Source-store-ahead-of-deploy drift findings for the files this phase
  edits are expected until Phase 6 regenerates the deploy." The targeted suite had already run and
  passed one line above the full-sweep requirement — the full sweep added no new information about
  the edit itself, only the (self-predicted, self-discounted) drift noise.
- Phase 6 ("Redeploy and Final Gate Set," the plan's true final phase) also declares `**Verification
  Tier**: full` (line 577) and runs `timeout 3000 bash .claude/scripts/verify-deploy.sh` (line 547),
  as the invariant requires.
- Under the new guidance (counterfactual): Phase 4 would instead declare a cheaper tier (`local` or
  `interface`, since the edit is confined to `hooks/guard-destructive-git.sh` and
  `scripts/lib/push-grant-lib.sh`, both already covered end-to-end by
  `test-guard-destructive-git.sh`), state the justification "`test-guard-destructive-git.sh` covers
  this edit directly; a full sweep's drift findings are known noise until Phase 6 redeploys," and
  run `bash agent-system/extensions/core/scripts/tests/run-all.sh --only
  test-guard-destructive-git.sh` in place of the full `verify-deploy.sh` — Phase 6 is untouched and
  still runs the complete gate set. This directly satisfies acceptance items 1 and 2 as a worked
  design (not yet executed against a live task; that is plan/implement work, out of scope here).

**Non-final `full` remaining legitimate (acceptance item 3):**

A phase whose edit genuinely spans shared/global surface is a textbook case where `full` at a
non-final phase is still correct and should remain easy to state. No example in the live corpus was
found where a *non-final* `full` was both warranted and explicitly justified in prose (the task
361 Phase 4 case is the opposite — warranted-looking but actually over-broad), but
`task-breakdown.md:171`'s worked `full` example ("touches shared token generation, email delivery,
and auth state — multiple auth-dependent flows across the codebase") is exactly the shape a
justification line should take: it names the specific cross-cutting surface, not just "to be
safe." The plan phase should reuse this example as the template for what satisfies the new
requirement, so the justification requirement reads as "name the blast radius," not "write an
essay."

**No independent fifth copy of the tie-break rule (acceptance item 5):**

A corpus-wide grep for `"strictest applicable tier"` and `"Verification Tier"` across
`agent-system/extensions/**/*.md` surfaced, beyond the four in-scope files: `docs/guides/user-guide.md`,
`rules/plan-format-enforcement.md`, `context/contracts/pre-edit-gate.md`,
`context/contracts/reference-grounding.md`, `context/standards/git-workflow-narrative.md`,
`docs/architecture/batch-admit-schema.md`, `context/patterns/batch-orchestration-guardrails.md`,
and `agent-system/extensions/books/context/project/books/standards/observation-record.md`. Every
one defers by cross-reference ("see plan-format.md's `## Verification Tiers` section") rather than
restating the rule's substance. The one soft caveat: `rules/plan-format-enforcement.md:43`
currently says "See plan-format.md's `## Verification Tiers` section for the full vocabulary,
blind-spot definitions, **and the tie-break-upward rule**." Once the tie-break is qualified
(no longer unconditionally "upward" at non-final phases), this descriptive phrase becomes mildly
stale — it is a label pointing at the rule, not a copy of it, so it is outside the four-file scope,
but the implementing dispatch should consider a one-line wording touch-up there (e.g.
"tie-break rule" instead of "tie-break-upward rule") as a low-cost incidental fix, not a scope
expansion.

**Scope exclusion of `reviser-agent.md` confirmed correct:**

Zero matches for "Verification Tier" or "tier" anywhere in `agents/reviser-agent.md`. It defers
to `plan-format.md` structure at line 16 ("always load"), line 93 ("Follow plan-format.md structure
exactly"), and line 177 ("Follow plan-format.md structure exactly for revised plans," in the MUST
DO list). No independent tier-assignment logic exists in the revise path that could reintroduce an
unjustified `full` outside of what `plan-format.md` itself governs. No follow-up task is warranted
on this point.

### External Resources

Not applicable — this is an internal planning-guidance change with no external library or API
surface.

## Decisions

- **Scope is confirmed as exactly the four named files**; no fifth file needs editing to satisfy
  acceptance item 5's "no surviving copy" requirement, modulo the one-line incidental wording note
  above in `rules/plan-format-enforcement.md` (optional, not required).
- **The dependency (task 366) is satisfied and its mechanism is citable by name**: `run-all.sh
  --only SUITE[,SUITE,...]` plus `suite_selection_select` from `suite-selection-lib.sh`. The
  guidance change can reference these directly rather than describing a hypothetical mechanism.
- **The live instance (task 361 Phase 4) is confirmed as an accurate, concrete worked example**
  for the plan to use when demonstrating the new guidance (acceptance items 1 and 2), including a
  specific replacement verification command.
- **`reviser-agent.md` remains out of scope**; research found no gap that would require revisiting
  this exclusion.

## Recommendations

1. **Qualify `plan-format.md:271`'s tie-break rule, not replace it.** Recommended replacement
   shape: keep "when uncertain, apply the strictest applicable tier" as the rule for the *final*
   phase (and for genuine uncertainty at any phase), and add an explicit carve-out: "a non-final
   phase choosing `full` states why a cheaper tier does not cover the edit" — consistent with the
   dispatch's own framing that this is a qualification of the existing line, not a new, separate
   rule.
2. **Use a required, conditional field — not prose-only guidance — for the justification**,
   modeled directly on the existing conditional `**Scope Hypothesis**:` field pattern already in
   `planner-agent.md:313-315` (required only when a phase asserts a count/file-list/scope
   estimate). Recommended field name: `**Tier Justification**:`, required precisely when
   `**Verification Tier**: full` AND the phase is non-final; omitted otherwise (mirrors the
   `**Commit Mode**` omit-by-default convention already in use). This is checkable by
   `planner-agent.md`'s authoring checklist exactly the way `**Scope Hypothesis**` already is,
   satisfying acceptance item 6 without requiring any `validate-artifact.sh` change (though adding
   one later remains a reasonable follow-on, not required for this task).
3. **Settle "final phase" explicitly** — this is a real gap, not named in the dispatch, that the
   plan must resolve before the justification requirement is checkable. Recommended resolution:
   define "the final phase" as the terminal node of the plan's own wave/dependency graph — the
   phase no other phase's `**Depends on**:` requires further work after, which in every plan
   observed in this corpus coincides with simply the highest-numbered phase. State this plainly in
   `plan-format.md`'s `## Verification Tiers` section once, rather than inventing a new marker
   field; `planner-agent.md`'s Step 6 "Build Wave Map" already computes the wave structure needed
   to identify it, so no new computation is required, only a one-sentence definition.
4. **`task-breakdown.md`'s two bare templates (`:76-78`, `:94`) should show the conditional
   justification field exactly as `planner-agent.md`'s phase template will**, and the existing
   worked `full` example at `:171` should be cited (or its phrasing reused) as the model for what a
   satisfying justification looks like, since it already demonstrates "name the specific blast
   radius" rather than "to be safe."
5. **`phase-closure.md:53` and `:167-169` need one clause each**, not a rewrite: at `:53`, add that
   a cheaper non-final tier with its justification stated is a legitimate way to be the
   smallest-remaining-work phase (so cheapest-closure-first ordering doesn't get read as
   second-guessing the tier choice); at `:167-169`, no change to the run-and-observe rule itself is
   needed — it already applies uniformly regardless of tier — but the citing dispatch should
   confirm this with a cross-reference rather than new prose, keeping the edit minimal.
6. **Do not present `--skip-slow` as a tier, and do not let a passing cheaper tier be read as
   discharging the doc-sync-pin evidence** (ROADMAP Settled decision 15, echoed verbatim in
   `shell-script-testing.md:178-183` and in `suite-selection-lib.sh`'s own header per the 366
   summary). The new guidance text should either explicitly echo this caveat or cross-reference
   `shell-script-testing.md`'s existing wording rather than restating it a third time.
7. **When implementing, replay the task 361 Phase 4 counterfactual concretely** as acceptance item
   2 requires: state the new tier (`local` or `interface`), the justification text, and the
   replacement command `bash agent-system/extensions/core/scripts/tests/run-all.sh --only
   test-guard-destructive-git.sh`, and confirm this suite genuinely covers both edited files
   (`hooks/guard-destructive-git.sh`, `scripts/lib/push-grant-lib.sh`) before citing it as the
   covering suite.

## Risks & Mitigations

| Risk | Mitigation |
|------|------------|
| A required `**Tier Justification**` field adds authoring friction broadly enough that planners start marking every non-final `full` with a throwaway justification string, defeating the purpose | Give the authoring checklist (and the worked example at `task-breakdown.md:171`) a concrete bar: the justification must name the specific suite/module/blast-radius, not a generic phrase; `validate-artifact.sh` enforcement, if added later, should check for *presence* only (content quality stays a review-time judgment, consistent with the advisory-first precedent already documented for `**Verification Tier**` itself) |
| "Final phase" is left implicit and two authors (or an author vs. the validator) disagree about which phase is final in a plan with non-linear waves | Adopt Recommendation 3 (terminal-node-of-wave-graph definition) explicitly in `plan-format.md`, not left to convention |
| The incidental staleness in `rules/plan-format-enforcement.md:43` ("tie-break-upward rule") is left unfixed, slightly misdescribing the now-qualified rule | Low severity (descriptive label, not a second copy of the rule); optional one-line fix noted in Findings, not required for acceptance |
| A future revise pass (`reviser-agent.md`) adds a new phase without applying the new justification requirement, since revision isn't exercised by this task's acceptance demonstration | Already mitigated structurally: `reviser-agent.md` defers wholly to `plan-format.md` structure (confirmed, zero independent tier logic); no code path exists to bypass it, so no action needed beyond what already exists |

## Context Extension Recommendations

- **Topic**: "final phase" identification in a multi-wave plan.
- **Gap**: No existing context file states how to determine which phase in a plan is "the final
  phase" for purposes of phase-position-conditional rules (this task's justification requirement,
  and the pre-existing invariant that only the final phase must retain `full`). The concept is used
  informally (`planner-agent.md:153`'s roadmap-update example, `plan-format.md:273-277`'s invariant)
  but never defined.
- **Recommendation**: Add a short, explicit definition to `plan-format.md`'s `## Verification
  Tiers` section (or a adjacent subsection) the next time that file is touched — this task's own
  implementation phase is the natural place, per Recommendation 3 above, rather than opening a
  separate context-extension task for a one-sentence addition.

## Appendix

- Search queries/commands used: `jq` queries against `specs/state.json` for task 366/368 status
  and full task-368 description; `grep -n` against `plan-format.md`, `planner-agent.md`,
  `task-breakdown.md`, `phase-closure.md`, `validate-artifact.sh`, `reviser-agent.md`,
  `verify-deploy.sh`, `shell-script-testing.md`, and `ROADMAP.md` for every anchor cited in the
  dispatch; corpus-wide `grep -rln "strictest applicable tier\|Verification Tier"` across
  `agent-system/extensions/`; `git log --all --oneline | grep "task 361"` to locate the archived
  task 361 plan (not present under `specs/` top level; found under `specs/archive/`).
- Key files read: `specs/archive/361_reclassify_bare_git_stash_as_destructive/plans/01_reclassify-stash-destructive.md`
  (Phases 1-6, full); `specs/366_suite_level_selection_within_gate_8/summaries/01_run-all-suite-selection-summary.md`;
  `specs/366_suite_level_selection_within_gate_8/reports/01_suite-level-selection-mechanism.md`
  (excerpt); `agent-system/extensions/core/scripts/lib/suite-selection-lib.sh` (function names
  only); `agent-system/extensions/core/scripts/tests/run-all.sh` (header/usage lines);
  `agent-system/extensions/core/scripts/validate-artifact.sh` lines 39-324;
  `agent-system/extensions/core/context/standards/shell-script-testing.md` (measured-figures and
  Settled-decision-15 passages).
- Note on the dispatch's cited "92 suites / 44,682 lines" figure: `specs/ROADMAP.md` (Next section,
  line 40) now records this as **stale** — task 366's own acceptance proof re-measured the battery
  at 123 suites after landing. The dispatch explicitly says "USE THIS, DO NOT RE-DERIVE" for the
  cost-framing purpose (establishing that `full` is expensive), and that purpose holds regardless of
  the exact suite count; this note is informational only and does not change any finding or
  recommendation above.
