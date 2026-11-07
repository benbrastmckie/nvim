# Research Report: Plan-Format Tier Justification Fixes

**Task**: 493 - Plan format Tier Justification fixes
**Started**: 2026-11-06T00:00:00Z
**Completed**: 2026-11-06T00:00:00Z
**Effort**: small (two narrow textual edits plus one scope decision)
**Dependencies**: None
**Sources/Inputs**: Codebase (agent-system/extensions/core/context/formats/plan-format.md, scripts/lib/suite-selection-lib.sh, scripts/validate-artifact.sh, hooks/validate-plan-write.sh), direct measurement (`suite_selection_select`), dispatch citations from the originating repository's issues.jsonl
**Artifacts**: This report
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- Defect 1 (dead entry point) is confirmed by direct inspection: `plan-format.md` line 339
  hardcodes the source-store-only path `agent-system/extensions/core/scripts/tests/run-all.sh`
  as *the* suite-subset narrowing command, with no deploy-form alternative, even though the
  sibling bullet two lines later (line 343) and the "Batch-aware deferral" section
  (lines 420-429) already state and use the correct dual-form, resolve-whichever-exists
  convention. The fix is a reference, not a restatement: point line 339 at that existing
  convention instead of hardcoding one form.
- Defect 2 (unmeasured Tier Justification claim) is confirmed by direct re-measurement:
  `suite_selection_select specs/ROADMAP.md` resolves to two real covering suites
  (`test-engine-written-state-paths-lib.sh`, `test-roadmap-generation.sh`), not the
  `__FULL_SWEEP__` sentinel a prior plan asserted for that path.
- The measurement call itself is effectively free: `source .claude/scripts/lib/suite-selection-lib.sh && suite_selection_select specs/ROADMAP.md`
  measured at 53ms wall-clock on this host — a pure path-matching function, not a build or test
  run. This changes the cost/benefit calculus the dispatch asks to weigh honestly: the
  "every non-final phase pays a cost" framing that is genuinely true of a `full` gate run (which
  this change does not touch) is NOT true of the selector call itself.
- **Ruling (recorded in Decisions below)**: add a mechanical lint, not a prose-only
  requirement, scoped narrowly to Tier Justification lines that name a `--only SUITE[,...]`
  suite subset or invoke the `__FULL_SWEEP__` sentinel. Prose-only would repeat the exact failure
  mode defect 2 demonstrates (an assertion nobody checked); a lint is cheap to run because the
  thing it re-derives is cheap to compute; and the codebase already has a proven, low-risk
  rollout pattern for exactly this kind of plan-level check (advisory warn in
  `validate-artifact.sh`, promotable to `--strict`/error later, firing automatically through the
  existing `hooks/validate-plan-write.sh` PostToolUse hook with zero new gate wiring).
- Both defects live in the same subsection (`**Tier Justification**:`, plan-format.md
  ~lines 332-345) and were filed together deliberately; no other open task's declared
  `file_scope` claims either defect.

## Context & Scope

Two minor defects were filed against `agent-system/extensions/core/context/formats/plan-format.md`
from the conclusion stage of an `/orchestrate` run over a task in a different repository
(`~/Projects/BimodalLogic`), both inside the `**Tier Justification**:` block that governs how a
non-final phase in an implementation plan may declare a verification tier cheaper than `full`.
This repository (`~/.config/nvim`) is the agent-system source store: `plan-format.md` here is the
edit target per `.claude-extensions.json`'s `core` entry (`source_dir`:
`agent-system/extensions/core`), and any fix must be redeployed via `deploy-headless.sh` to reach
consumer repositories such as the one that filed the defects.

Scope is deliberately narrow: this record only touches `plan-format.md` (and, if the lint remedy
is selected, the lint script / its test / any gate wiring the plan phase scopes separately — the
hard constraints forbid widening `file_scope` here). The tier taxonomy, the final-phase `full`
invariant, and the `__FULL_SWEEP__` documentation itself are explicitly out of scope and were not
touched by this research.

## Findings

### Codebase Patterns

**Defect 1 — line 339's hardcoded path.** `plan-format.md:339` reads:

```
- a suite subset within Gate 8: `bash agent-system/extensions/core/scripts/tests/run-all.sh --only SUITE[,SUITE,...]`,
```

This is the *only* unpaired occurrence of that bare source-store path in the file. A second
occurrence at line 424 (`the parallel \`bash agent-system/extensions/core/scripts/tests/run-all.sh --only SUITE[,SUITE...]\`
... form`) is explicitly labelled as the source-store-repository form and paired with the deploy
form two lines above it (`bash .claude/scripts/tests/run-all.sh --only SUITE[,SUITE...]`,
line 422). The file's own "Batch-aware deferral" section (lines 420-429) states the general rule
line 339 should be following: "The composer resolves and interpolates whichever of the two
actually exists in the repository the dispatch is running in (never a hardcoded path that cannot
resolve there); if neither exists, the directive degrades to stating the full gate set as such
instead of naming a dead path." Verified directly: this repository (the source store) has both
`.claude/scripts/tests/run-all.sh` and `agent-system/extensions/core/scripts/tests/run-all.sh`
on disk; a pure deploy-target repository (as cited for `~/Projects/BimodalLogic`) has only the
former.

**Defect 2 — the selector claim.** Re-running the selector directly from this repository's
deployed tree:

```
$ source .claude/scripts/lib/suite-selection-lib.sh && suite_selection_select specs/ROADMAP.md
test-engine-written-state-paths-lib.sh
test-roadmap-generation.sh
```

This reproduces the dispatch's own measurement exactly: two real covering suites, not the
`__FULL_SWEEP__` sentinel a prior Tier Justification line asserted for the same path. The
`suite_selection_select` function (`scripts/lib/suite-selection-lib.sh:199-220`) is a pure
in-process path-matching loop over `_ssl_resolve_one`; it performs no build, no test execution,
and no filesystem mutation. Measured wall-clock for the call above (including sourcing the
library): 53ms real / 22ms user. This is the key fact the cost side of the dispatch's "weigh
honestly" framing turns on: the expensive thing this tiering system exists to avoid is a full
Gate 8 run (dominated by the shell-suite battery per
`context/standards/shell-script-testing.md`'s measured figures), not a selector lookup. A
measurement *requirement* does not inherit Gate 8's cost; it is closer in cost to a grep.

**Existing enforcement precedent.** `scripts/validate-artifact.sh`'s `plan` branch already
implements exactly the rollout pattern this decision should reuse: it checks each phase's
`**Verification Tier**` field, emits `log_warn` for a missing/malformed one by default (exit 0
on warnings alone), and only escalates to a hard failure under `--strict`
(`rules/plan-format-enforcement.md`'s "Current enforcement level" paragraphs document this
explicitly as a deliberate, not-yet-promoted stance, with its own promotion criterion: promote
once no non-terminal plan under `specs/` lacks the field). `hooks/validate-plan-write.sh` is a
PostToolUse hook that already fires `validate-artifact.sh` automatically on every
`Write`/`Edit` to `specs/*/plans/*.md` — this means a new check added inside
`validate-artifact.sh`'s existing `plan` branch gets automatic write-time enforcement for free,
with no new gate or hook wiring required beyond the script itself and its test suite
(`scripts/tests/test-validate-artifact.sh`).

**Phase structure available to a lint.** The task-breakdown template
(`context/workflows/task-breakdown.md:74-194`) shows each phase step carrying its own
`**Files:**` bullet listing the files that step touches; a lint can collect a phase's touched
paths by unioning its steps' `**Files:**` entries (or, more coarsely, the task's declared
`file_scope`) and feed them to `suite_selection_select` for comparison against the phase's
`**Tier Justification**:` line.

### External Resources

Not applicable — this is a closed, local-codebase defect with no external dependency; no web
research was needed or performed.

## Decisions

1. **Defect 1 ruling**: fix line 339 by reference, not by restatement. Replace the hardcoded
   bare path with the dual-form convention already stated in "Batch-aware deferral"
   (lines 420-429), naming both forms inline (as the sibling bullet at line 343/424 already
   does) and pointing to that section by name for the resolve-whichever-exists rule, rather than
   re-deriving a second copy of that rule at line 339. This keeps the override section the single
   statement of the convention, per the hard constraints.

2. **Defect 2 ruling: add a mechanical lint, scoped narrowly.** `plan-format.md`'s Tier
   Justification requirement SHOULD require the author to have actually run
   `suite_selection_select` on the phase's touched path(s) and quote its real output, and this
   requirement SHOULD be backed by a mechanical check in `scripts/validate-artifact.sh`'s `plan`
   branch rather than prose alone. Reasoning, weighed explicitly as the dispatch requests:
   - **Against the measurement requirement**: plan-format.md is already long and competes for an
     author's attention; a document-level honor-system is simpler to state.
   - **For the measurement requirement, and decisively so**: defect 2 is precisely the failure a
     prose-only rule cannot prevent — nothing forced the prior author to actually invoke the
     selector before writing a confident claim about its output, and the claim was false. A Tier
     Justification is the one sentence that licenses a phase to verify below `full`; an
     unmeasured claim there can silently under-verify a phase, which is the exact harm the field
     exists to prevent.
   - **Why a lint over prose, decisively**: the thing being re-derived (`suite_selection_select`
     over a handful of paths) costs ~50ms, not a Gate 8 run. The dispatch's own cost-of-guessing
     framing — "every non-final sub-`full` phase pays a selector invocation at plan time" — is
     true but the payment is negligible; it is not in the same cost class as the `full`-gate
     cost analysis that originally motivated the tier system's existence (which this change does
     not touch). Given the check is nearly free and the failure mode is a silent false claim a
     human reviewer is unlikely to catch by eye (the prior author presumably believed their own
     assertion), mechanical enforcement dominates prose on both cost and reliability grounds.
   - **Why the scope is narrow**: the lint applies only to a Tier Justification line that (a)
     names a `--only SUITE[,SUITE...]` suite subset, matched against `suite_selection_select`'s
     actual resolution for the phase's touched paths, or (b) invokes the `__FULL_SWEEP__`
     sentinel, verified by confirming the selector genuinely returns that sentinel for those
     paths. It does NOT extend to the gate-subset mechanism (`--only-gate N[,M...]`), which is a
     different narrowing mechanism not grounded in `suite_selection_select` and not implicated by
     either filed defect — extending scope there would be inventing a third defect nobody
     measured.
   - **Integration point**: `scripts/validate-artifact.sh`'s existing `plan` branch, following
     its own established advisory-first pattern (warn by default, `--strict` escalates) rather
     than landing as a day-one hard failure — consistent with how the Verification Tier field
     check itself was rolled out, and avoiding breaking plans authored before this check existed.
     Because `hooks/validate-plan-write.sh` already invokes `validate-artifact.sh` generically on
     every plan write, this requires no new PostToolUse hook and no new `verify-deploy.sh` gate
     entry — only the validator script and its test suite change. (Per the hard constraints,
     widening `file_scope` to cover that script/test/gate-wiring is left for the plan phase to
     declare; this record intentionally states only `plan-format.md` as in scope here.)

## Recommendations

1. Edit `plan-format.md:339` to reference the "Batch-aware deferral" section's dual-form
   convention instead of hardcoding the source-store-only path, mirroring the phrasing already
   used at line 424 (deploy form first, source-store form labelled as such, with a pointer to the
   resolve-whichever-exists rule rather than a restatement of it). After the edit, a grep for the
   bare `agent-system/extensions/core/scripts/tests/run-all.sh` path should return only
   occurrences explicitly paired with the deploy form or explicitly labelled as the source-store
   form — matching this task's acceptance criterion.
2. Add prose to the Tier Justification subsection making the measurement obligation explicit:
   a justification naming a suite subset or the `__FULL_SWEEP__` sentinel is only honest if the
   author ran `suite_selection_select` on the phase's touched paths and the line's claim matches
   that output.
3. Extend `scripts/validate-artifact.sh`'s `plan` branch with a new, advisory-by-default check
   implementing the lint described in Decision 2: for each non-final phase, if its Tier
   Justification line names a `--only SUITE[,...]` list or the `__FULL_SWEEP__` sentinel, collect
   the phase's touched files (from its steps' `**Files:**` bullets, falling back to the task's
   declared `file_scope` if a phase has none), call `suite_selection_select` on them, and compare
   against the declared claim; `log_warn` on mismatch by default, fail under `--strict`.
4. Add a fixture-based test pair to `scripts/tests/test-validate-artifact.sh`: one fixture plan
   whose Tier Justification carries a fabricated/stale selector result (expected to fail under
   `--strict`), and one whose justification carries the actually-measured result for its touched
   paths (expected to pass) — satisfying this task's acceptance criterion directly.
5. When the plan phase scopes implementation, widen `file_scope` beyond `plan-format.md` to
   include `scripts/validate-artifact.sh`, `scripts/tests/test-validate-artifact.sh`, and any
   gate-wiring touched (expected to be none beyond the validator and its test, per the Findings
   above, since the existing hook already invokes the validator generically) — per this
   dispatch's hard constraints, this record itself declares only `plan-format.md`.

## Risks & Mitigations

- **Risk**: a mechanical lint that mis-parses a well-formed Tier Justification sentence could
  produce a false-positive warning on an unrelated plan. **Mitigation**: ship it advisory-first
  (warn, not fail, outside `--strict`) exactly as the existing Verification Tier check was rolled
  out, so no plan currently passing validation starts failing silently; promote later only once
  swept against the existing plan corpus, mirroring that check's own documented promotion
  criterion.
- **Risk**: scope creep into the gate-subset (`--only-gate`) narrowing mechanism, which the
  dispatch's hard constraints did not ask to be touched. **Mitigation**: the Decision above states
  explicitly that the lint's scope is bounded to `suite_selection_select`-grounded claims only.
- **Risk**: a phase's touched-files list is ambiguous when a step's `**Files:**` bullet is
  missing or when the phase relies solely on the task-level `file_scope`. **Mitigation**: the
  plan phase should decide the exact fallback precedence (steps' `**Files:**` union first, task
  `file_scope` as fallback) and document it in the lint's own header comment, matching the
  pattern other validate-artifact.sh checks already use for similar fallbacks.

## Context Extension Recommendations

- none — this is a self-contained documentation/tooling fix with existing precedent
  (`rules/plan-format-enforcement.md`, `validate-artifact.sh`'s advisory-first rollout pattern)
  already covering the enforcement-maturity question a future reader would otherwise need
  answered.

## Appendix

- Direct measurements performed this run:
  - `python3 -c "..." ` against `.claude-extensions.json` to confirm `core`'s `source_dir`
    resolves to `agent-system/extensions/core`.
  - `grep -n "agent-system/extensions/core/scripts/tests/run-all.sh" agent-system/extensions/core/context/formats/plan-format.md`
    — confirms exactly two occurrences (lines 339, 424), only the second labelled/paired.
  - `source .claude/scripts/lib/suite-selection-lib.sh && suite_selection_select specs/ROADMAP.md`
    — reproduces the dispatch's own measurement (`test-engine-written-state-paths-lib.sh`,
    `test-roadmap-generation.sh`), confirming defect 2 as filed.
  - `time (...)` wall-clock of the same selector call: 53ms real.
  - `grep -rln "validate-artifact.sh" agent-system/extensions/core/` and a read of
    `hooks/validate-plan-write.sh` — confirms the automatic write-time enforcement path a new
    check would ride for free.
- Citations (originating repository, not this one):
  `~/Projects/BimodalLogic/specs/878_lplus_ztime_decidability_paper_proof_repair/issues.jsonl`,
  entries `iss_1793905878455_9R7xHR` (defect 1) and `iss_1793905661566_XjC7uq` (defect 2).
