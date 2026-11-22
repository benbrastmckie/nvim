# Implementation Summary: Task #504

- **Task**: 504 - Lean Goals-block harvest contract (MEASURED {871, iss_1793913951568_HzkOMJ})
- **Status**: [COMPLETED]
- **Started**: 2026-11-22T00:00:00Z
- **Completed**: 2026-11-22T08:30:00Z
- **Effort**: ~3 hours
- **Dependencies**: None
- **Artifacts**: plans/01_goals-block-harvest-contract.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md

## Overview

`lean-plan-compliance-check.sh`'s Goals-prose fallback harvest swept every backticked token in
the whole Goals range, so a binder name or a cross-referenced pre-existing identifier cited in a
bullet's trailing descriptive prose was wrongly harvested as a goal declaration, producing
permanent spurious `[MISSING]` failures. The decision this record owed was already settled by
research: narrow the script to the documented contract (rejected alternative: widen the
document). This task ports `lean-challenge-snapshot.sh`'s own per-bullet leading-identifier-run
rule into the bash/grep sibling, re-baselines the four existing test cases the narrowing
legitimately changes, adds the record's required regression coverage, and corrects a stale
fixture comment that misstated already-fixed behaviour.

## What Changed

- `agent-system/extensions/lean/scripts/lean-plan-compliance-check.sh` — the Goals-prose fallback
  harvest narrowed from a whole-range backtick sweep to a per-bullet leading-identifier-run
  extraction; a new `LEADING-IDENTIFIER-RUN GOALS-PROSE HARVEST` header-comment section (the
  third narrowing of this one harvest) documenting the rule and its `SHARED FRAGILITY`
  cross-reference to `lean-challenge-snapshot.sh`'s `extract_goal_names()`; a one-line comment at
  the Goals-range `sed` call recording the deferred header-shape-acceptance gap.
- `agent-system/extensions/lean/scripts/tests/test-lean-plan-compliance-check.sh` — C13
  re-baselined to `skipped` (exit 0, both polarities) with an explicit `SUPERSEDED` header
  comment, fixture text unchanged; C14/C15/C16 Goals bullets rewritten into leading-run-conformant
  shape with per-case notes; new case C20 preserving C13's refutation-polarity regression intent
  on a conformant shape; new case C21 (the record's minimum verification bar — measured-defect
  regression, no Challenge Statements section, exact-harvested-set assertion); new case C22
  (first coverage of the `CHALLENGE-STATEMENTS-PREFERRED HARVEST` feature's precedence over the
  Goals-prose fallback). Suite grew from 19 to 22 cases, all green.
- `agent-system/extensions/lean/scripts/tests/fixtures/challenge/plan_goals_preamble.md` — the
  preamble paragraph's stale final sentence ("the snapshot tool reads every backticked token
  here as a Goal") corrected to state the current leading-run rule; every other part of the
  fixture left byte-identical.

## Decisions

- Implemented the plan's "two-stage leading-run form" with the two bullet-marker-prefix
  quantifiers made POSSESSIVE (`^\s*+-\s*+\K(?:...)+`) rather than the plan's literal
  plain/greedy `\s*`. Verified mechanically, before editing, that the plain form lets PCRE
  backtrack the bullet's single separating space into the `(?:...)+` alternation (which itself
  accepts a bare whitespace character) whenever the bullet's first content is non-backtick prose
  — producing a spurious one-character match instead of no match at all, reproduced live against
  the C13 archived-plan shape. The possessive fix is surgical: the alternation's own content and
  quantifier, and the existing stage-two re-extraction pipeline, are unchanged from the plan's
  intent. Re-verified against the plan's own three research-time test shapes (measured-defect
  prose, four-identifier conformant run, prose-leading bullet) and the full Scope Hypothesis
  table, all matching exactly.
- C22's "assert the harvest source" verification was discharged structurally (exact one-`[OK]`-
  line count plus absence of every trailing-prose name) rather than via a literal `harvest_source`
  string match: that variable is mechanically confirmed to be echoed only on the `skipped`
  verdict path, never on a passing or failing one.
- Both readers' harvest implementations stay independently maintained (bash/grep here,
  Python there), per the existing `SHARED FRAGILITY` convention — no unification attempted.

## Plan Deviations

- **Phase 1, "Replace the fallback harvest's single whole-range sweep..."** altered: possessive
  `\s*+`/`\s*+` quantifiers used in place of the plan's literal plain `\s*`/`\s*`, for the
  correctness reason recorded in Decisions above. Annotated inline in the plan checklist.
- **Phase 2, C22's "assert the harvest source reported in the skipped/verdict path"** altered:
  discharged structurally rather than via a literal output-string match, for the reason recorded
  in Decisions above. Annotated inline in the plan checklist.
- No other deviations; all other plan steps were followed as written.

## Verification

- Build: N/A (bash scripts, no build step).
- Tests:
  - `bash agent-system/extensions/lean/scripts/tests/test-lean-plan-compliance-check.sh` — 22
    passed, 0 failed, exit 0 (baseline was 19 passed, 0 failed before this task).
  - `bash agent-system/extensions/lean/scripts/tests/test-lean-challenge-snapshot.sh` — 37
    passed, 0 failed, 0 skipped, exit 0 — unchanged from the pre-edit result.
  - `bash .claude/scripts/lint/lint-shellcheck.sh agent-system/extensions/lean/scripts/lean-plan-compliance-check.sh agent-system/extensions/lean/scripts/tests/test-lean-plan-compliance-check.sh`
    — exit 0, 0 findings.
  - The measured defect's exact prose shape (one leading identifier plus a binder name and two
    pre-existing lemma names in trailing prose, no Challenge Statements section) was reproduced
    live and yields `[OK] foo_bar` alone, `COMPLIANCE_CHECK: passed`, exit 0 — no `P`, `hP`,
    `plusValidIn_reflectTime`, or `lcN_plusValidZTime` line anywhere in the output.
  - C21 was confirmed to genuinely fail (four spurious `[MISSING]` lines, `COMPLIANCE_CHECK:
    failed`) against a scratch copy of the script with the narrowing reverted — the regression
    coverage is non-vacuous. The scratch copy was never committed.
  - This task's three declared files are fully committed with no pending diff; `git status
    --short` shows other paths, but every one belongs to a concurrently-dispatched sibling
    task's own in-flight work this cycle (tasks 451 and 683, plus shared specs/ event logs),
    outside this task's own `file_scope` — not a foreign modification of this task's own files.
- Files verified: Yes (all three target files exist, are committed, and the fixture's `git diff`
  shows only the intended preamble-sentence change).
- Batch Gate Deferral (Phase 4, Verification Tier: full): discharged against the scoped tier per
  this dispatch's own directive. `bash .claude/scripts/verify-touched.sh` (no arguments) was run
  twice during this phase; the first invocation's own verdict line reported an overall failure,
  but the captured tail showed 98 passed/0 failed for the suites it did show — the failure
  originated above the captured window, and a concurrent sibling (tasks 451/683) was actively
  mutating the shared working tree during the multi-minute run. A clean, untruncated re-run
  immediately afterward returned `overall_rc 0` (60 suites + 3 owed, 98 passed/0 failed/0
  skipped). Logged as a `verification flake` issue (minor severity) attributed to sibling-tree
  flux, not to this task's own edits. The complete gate set (`run-all.sh`/`verify-deploy.sh`
  unscoped) was deliberately NOT run independently in this dispatch, per the directive; it runs
  once for the whole batch at the orchestration close.

## Impacts

- A future plan author can again cite a cross-referenced pre-existing lemma or a binder name in
  Goals-block descriptive prose with backticks, without triggering a permanent spot-check
  failure — the stripped-backticks workaround the measured defect forced is no longer necessary
  and is not the settled answer.
- `lean-plan-compliance-check.sh` and `lean-challenge-snapshot.sh` now agree on harvest *breadth*
  (both apply the per-bullet leading-identifier-run rule); they still disagree on accepted
  Goals-header *shape* (see Follow-ups below) — this is a standing, separately-tracked residual,
  not newly introduced by this task.

## Follow-ups

- **Goals-range header-shape acceptance gap** (deferred, flagged in a code comment at the `sed`
  call, not fixed here): `lean-plan-compliance-check.sh`'s range anchor (`^\*\*Goals\*\*`) does
  not accept the list-item `- **Goals**:` form that `lean-challenge-snapshot.sh`'s `START_RE`
  (`^-?\s?\*\*Goals\*\*`) already accepts. A separate record is the right home for deciding
  whether to widen this script's range anchor to match its sibling's.
- **`context/project/lean4/patterns/goals-block-reader-parity.md` context file** (deferred, not
  created here): the research recommends documenting the two readers' parity (now matched on
  harvest breadth, still divergent on header shape per the point above) as a standing context
  file. Deferred because registering it requires editing
  `agent-system/extensions/lean/index-entries.json`, which concurrent sibling task 398 declares
  in its own `file_scope` this cycle.
- **Third narrowing of one harvest**: this task is the THIRD narrowing of
  `lean-plan-compliance-check.sh`'s Goals-prose fallback harvest (after the reserved-keyword
  denylist and the colon-optional Goals-range widening). The two readers' harvest *breadth* is
  now in agreement; their accepted *header* shapes are not — the standing residual the deferred
  parity context file above would document.
- A `verification flake` issue was logged (see Verification above) for the transient first
  `verify-touched.sh` failure signal; no code change was warranted since the re-run was clean.

## References

- Report: `specs/504_lean_goals_block_harvest_contract/reports/01_goals-block-harvest-contract.md`
- Plan: `specs/504_lean_goals_block_harvest_contract/plans/01_goals-block-harvest-contract.md`
- Progress: `specs/504_lean_goals_block_harvest_contract/progress/phase-{1,2,3,4}-progress.json`
- Handoffs: `specs/504_lean_goals_block_harvest_contract/handoffs/phase-{1,2,3}-handoff-*.md`
