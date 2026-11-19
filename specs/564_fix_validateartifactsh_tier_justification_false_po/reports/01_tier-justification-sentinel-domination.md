# Research Report: Task #564

**Task**: 564 - Fix validate-artifact.sh Tier Justification false-positive (sentinel domination
in `suite_selection_select`)
**Started**: 2026-11-19
**Completed**: 2026-11-19
**Effort**: ~2-3 hours (selector change + consumer-compatibility audit + fixtures, per plan-format.md tiering)
**Dependencies**: Task 505 (`suite_selection_non_core_extension_paths`) -- already landed (archived,
[COMPLETED]); its mapping-walk change is already reflected in the live `suite-selection-lib.sh`
this report measures against. No remaining blocking dependency.
**Sources/Inputs**: Codebase (agent-system/extensions/core/scripts/lib/suite-selection-lib.sh,
validate-artifact.sh, verify-deploy.sh, verify-touched.sh, suite-resolver-lib.sh,
tests/test-run-all-selection.sh, tests/test-validate-artifact.sh), context/formats/plan-format.md,
specs/state.json, specs/archive/505_suite_selection_non_core_extension_paths
**Artifacts**: this report
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- **The defect is live and freshly reproduced.** `suite_selection_select` returns the
  `__FULL_SWEEP__` sentinel for the WHOLE multi-path call the instant any one given path is
  unmappable, discarding the real suite(s) every other, mappable path in the same call resolves
  to. Verified today: `lint/lint-agent-contracts.sh` alone resolves to 10 real suites;
  `scripts/audit-deletion-references.sh` alone correctly escalates to the sentinel (confirmed
  genuinely zero-referenced); the two together still collapse to pure `__FULL_SWEEP__`, losing
  all 10 real suites. `suite_selection_unmapped` on the same pair correctly names only the
  zero-reference path.
- **The fix belongs in `suite_selection_select` itself, not in validate-artifact.sh's
  consumption of it** -- plan-format.md's own "Enforcement level (Tier Justification
  measurement)" section states the check's scope is "bounded to claims grounded in
  `suite_selection_select`" and the dispatch's required fixtures (a)/(b) pin that function's own
  direct return value, not a filtered/pre-processed one. This is additional, independent
  grounding for the decision beyond the dispatch's own point (2) framing.
- **A real, already-tested compositional precedent exists in this corpus**:
  `scripts/lib/suite-resolver-lib.sh`'s own header explicitly documents wrapping
  `suite_selection_select` ONE PATH AT A TIME, "so one new/unmapped file in a touched set never
  drowns out the real suites the OTHER touched paths resolve to -- the exact collapse the
  originating record exists to prevent." Its `suite_resolver_resolve` already emits a
  `SELECT`/`UNRESOLVED` union shape. This is strong corroborating evidence for the compositional-
  union direction, though it is not a drop-in substitute (see Decisions below for why).
- **Blast radius beyond this record's declared two files is real and must be planned for.**
  Exactly two production call sites invoke the raw multi-path `suite_selection_select`:
  validate-artifact.sh's Tier Justification check (line 821) and verify-deploy.sh's Gate 8
  `--gate8-touched` narrowing (line 1536) -- and BOTH use the identical
  `[ #out -eq 1 ] && [ out[0] = sentinel ]` idiom to detect "no suite covers this." Changing
  `suite_selection_select`'s return contract so a mixed set's output is no longer a bare
  single-element sentinel array requires auditing (and very likely adapting) verify-deploy.sh's
  check too, or Gate 8's fail-safe fallback-to-full-battery behavior silently regresses. This is
  a mandatory, not optional, companion consideration for the implementing phase, even though
  verify-deploy.sh is not named in this record's declared file territory.
- **Recommended design** (for the implementing phase to weigh and rule on per point (2)):
  change `suite_selection_select` so each path's resolution is accumulated into the result
  union rather than short-circuiting on the first miss; an unmappable path contributes the
  sentinel token INTO that union (a "floor", matching the dispatch's own metaphor) rather than
  replacing it (a "ceiling"). The output for an all-unmappable set collapses by `sort -u` to the
  sentinel alone (point (3), fixture (b)); the output for a mixed set is the union of real suite
  basenames plus the sentinel token as one more line. Every existing "`-eq 1 &&
  ==sentinel`" call site (validate-artifact.sh's own check and verify-deploy.sh's Gate 8
  narrowing) must change to a "does the output set CONTAIN the sentinel" test to preserve
  Gate 8's fail-safe execution semantics while letting validate-artifact.sh's Tier Justification
  comparison branch treat the sentinel as a non-claimable, informational token it strips before
  computing missing/extra (see Decisions).

## Context & Scope

This task fixes a false-positive in `validate-artifact.sh`'s advisory-first Tier Justification
measurement check (plan-format.md's "Enforcement level (Tier Justification measurement)"
subsection): a plan phase whose `Files to modify` legitimately mixes a real, suite-covered
target with a path no suite covers (e.g. the plan's own bookkeeping file) has its selector
output collapse entirely to `__FULL_SWEEP__`, so an honest suite-list claim reads as fabricated.
The fix target is `agent-system/extensions/core/scripts/lib/suite-selection-lib.sh`'s
`suite_selection_select` (the single source of truth for touched-path -> covering-suite
resolution) and/or `validate-artifact.sh`'s consumption of it; the task's own point (2) requires
the implementing commit to rule on which, and this report provides grounding for that ruling
without making it, consistent with the dispatch's instruction.

Dependency task 505 (`suite_selection_non_core_extension_paths`) is already archived/
[COMPLETED] -- its per-extension mapping-walk change is already reflected in the library this
report measured against, satisfying this record's own "land it first, then re-derive" ordering
requirement. No blocking dependency remains for a planning pass today.

## Findings

### Codebase Patterns

**The defect, freshly reproduced against the live source store** (not relying solely on the
dispatch's own cited corroboration, which no longer reproduces -- see "Context Extension
Recommendations" / the carried-figure note below):

```
$ source agent-system/extensions/core/scripts/lib/suite-selection-lib.sh
$ suite_selection_select "$CORE/audit-deletion-references.sh"
__FULL_SWEEP__
$ suite_selection_select "$CORE/lint/lint-agent-contracts.sh" | wc -l
10
$ suite_selection_select "$CORE/lint/lint-agent-contracts.sh" "$CORE/audit-deletion-references.sh"
__FULL_SWEEP__
$ suite_selection_unmapped "$CORE/lint/lint-agent-contracts.sh" "$CORE/audit-deletion-references.sh"
<only the audit-deletion-references.sh path>
```

The mechanism (`suite-selection-lib.sh` lines 316-339, `suite_selection_select`): the function
loops over every given path, calling `_ssl_resolve_one` per path; the MOMENT any one path
resolves empty, it immediately `echo`s the sentinel and `return`s -- discarding every suite
already accumulated into `_ssl_all` for paths processed earlier in the same call. `_ssl_resolve_one`
itself (per-path, called correctly) and `suite_selection_unmapped` (which reports per-path, never
short-circuits) are both already correct; only `suite_selection_select`'s cross-path aggregation
has this flaw.

**Production call-site census** -- exactly two call sites invoke the raw multi-path function in
non-test code, and both share the identical detection idiom this defect breaks:

| Call site | Line | Purpose | Detection idiom |
|---|---|---|---|
| `validate-artifact.sh` | 821-825 | Tier Justification measurement (advisory lint) | `[ "${#_tj_actual[@]}" -eq 1 ] && [ "${_tj_actual[0]}" = "$SUITE_SELECTION_FULL_SWEEP_SENTINEL" ]` |
| `verify-deploy.sh` | 1536-1538 | Gate 8 `--gate8-touched` narrowing (execution-critical) | `[ "${#GATE8_SUITES[@]}" -eq 1 ] && [ "${GATE8_SUITES[0]}" = "${SUITE_SELECTION_FULL_SWEEP_SENTINEL:-__FULL_SWEEP__}" ]` |

Every OTHER production consumer of touched-path resolution in this corpus already avoids the raw
multi-path call, confirming the hazard is narrowly scoped to these two sites:

- `scripts/verify-touched.sh` (line 329) calls `suite_resolver_resolve`, not
  `suite_selection_select` directly.
- `scripts/report-suite-coverage.sh` (line 125) likewise calls `suite_resolver_resolve`.
- `scripts/lib/suite-resolver-lib.sh`'s own `_srl_default_resolve_one` calls
  `suite_selection_select` **single-path only** (one invocation per path, never multi-path) --
  immune to this defect by construction.
- `tests/run-all.sh`'s `--class`/`--tag`/`--cost-class` flags use the library's orthogonal
  declarative-selection functions (`suite_selection_by_class` etc.), never
  `suite_selection_select`/the sentinel at all.

**An existing, already-tested compositional-union precedent**: `suite-resolver-lib.sh`'s own
header (lines 11-17) states verbatim: *"`suite_selection_select PATH [PATH...]` escalates the
WHOLE multi-path call to the `__FULL_SWEEP__` sentinel the moment ONE path is unmappable ...
This wrapper calls it ONE PATH AT A TIME instead, so one new/unmapped file in a touched set
never drowns out the real suites the OTHER touched paths resolve to -- the exact collapse the
originating record exists to prevent."* Its `suite_resolver_resolve` (lines 193-283) accumulates
`SELECT <suite>` lines across all paths into a de-duplicated union and separately emits
`UNRESOLVED <path>` per unmapped path, rather than collapsing the whole call. This independently
confirms the defect's shape and the soundness of a compositional-union direction, but it is not
a drop-in fix for validate-artifact.sh's check specifically -- see Decisions.

**The authoring contract this check enforces** (plan-format.md, "`Tier Justification`" and
"Enforcement level (Tier Justification measurement)" subsections): "The claim is honest only
when the author ran it (or the underlying `suite_selection_select`) over the phase's `Files to
modify` paths and the line's suite names or sentinel match that output verbatim" and the
check's own documented "Scope" is explicitly "bounded to claims grounded in
`suite_selection_select`". This is independent textual grounding -- beyond the dispatch's own
point (2) framing -- that `suite_selection_select`'s own return value, not a richer derived
value (e.g. `suite_resolver_resolve`'s declared-backend-aware composition), is the quantity this
check is specified to measure. Substituting `suite_resolver_resolve` as the check's backend would
be a scope change beyond this record's NON-GOALS ("no broadening of what `__FULL_SWEEP__`
means"), since that function also consults the declared resolver backend and the explicit
`suite-selection-map.data`, which the Tier Justification contract does not mention.

**The documented canonical "Usage" snippet in `suite-selection-lib.sh`'s own header (lines
158-165) uses the identical fragile idiom**: `[ "${#_resolved[@]}" -eq 1 ] && [ "${_resolved[0]}"
= "$SUITE_SELECTION_FULL_SWEEP_SENTINEL" ]`, followed by an `else` branch that passes the WHOLE
resolved array to `run-all.sh --only`. If the return contract changes to a mixed
sentinel-plus-suites output, this canonical example becomes actively unsafe advice (it would
hand `run-all.sh --only` a comma list containing the literal token `__FULL_SWEEP__`, which is
not a real suite basename) and must be rewritten as part of any selector-layer fix -- one more
concrete, bounded piece of "necessary adaptation," not a second independent fix of the same
defect.

**Existing-test-suite baseline**: `tests/test-run-all-selection.sh` currently passes 36/36,
including its own Case 3 (lines 146-156), which pins the CURRENT (buggy) behavior as correct:
*"one unmappable path among several escalates the whole multi-path call"* -- PASS when the
mixed-path output equals the sentinel alone. **Any selector-layer fix necessarily flips Case 3's
expected outcome** (a mixed lint-fixture + zero-ref-candidate call should no longer collapse to
pure sentinel); updating Case 3's own assertion is in-scope implementation work alongside adding
the dispatch's required fixtures (a)/(b)/(c), not a separate concern.

**Dynamic-fixture-derivation conventions already established** in this test file (Case 1's
`ZERO_REF_CANDIDATE`, Case 3b/3c's `NONCORE_*`/`UNCOVERED_*` derivation loops): every fixture
input is derived live from the current corpus state rather than hardcoded, specifically to avoid
the corpus's own growth invalidating a literal fixture path (a hardcoded zero-reference
basename becomes, the moment the test naming it exists, a textual self-reference via stratum
(b)'s grep). New fixtures (a)/(b) should follow this same derivation discipline. A matching
precaution already exists in `test-validate-artifact.sh`'s Tier Justification fixture builder
(lines 566-583): `TJ_UNMAPPED_PATH="docs/nonexistent-fixture-subject-$$.md"` is PID-suffixed
specifically so the fixture path's own literal text, once committed, never becomes a spurious
stratum-(b) self-match against the test file containing it -- confirmed live by that file's own
comment ("a static placeholder resolved to `test-validate-artifact.sh` via that exact
self-match, not to the sentinel"). Fixture (c) (added to test-run-all-selection.sh per the
dispatch, invoking validate-artifact.sh as a subprocess against a synthetic plan) should reuse
this exact PID-suffix precaution rather than rediscovering it.

**Deployed/source-store parity confirmed today**: `agent-system/extensions/core/scripts/{lib/
suite-selection-lib.sh, validate-artifact.sh, tests/test-run-all-selection.sh}` are currently
byte-identical to their deployed `.claude/scripts/` counterparts, so "run from both a
source-store and a deployed vantage point" (the VERIFY section's closing instruction) is
presently achievable without a prior redeploy, though a redeploy is still required after this
task's own edits per its NON-GOALS framing ("no redeploy claimed as complete by this task beyond
the required deploy-headless.sh run").

### External Resources

Not applicable -- this is a pure internal shell-library/contract defect with no external
documentation dependency.

## Recommendations

1. **Fix `suite_selection_select` itself** (selector layer) rather than pre-filtering in
   validate-artifact.sh, per the independent "Scope: bounded to claims grounded in
   `suite_selection_select`" grounding above and the VERIFY fixtures' own wording (fixtures (a)
   and (b) pin the function's direct return value). Change `suite_selection_select` to accumulate
   every path's resolution into the union array (pushing the sentinel token itself into that
   array for an unmappable path) rather than `echo`-ing the sentinel and returning immediately;
   `sort -u` the final union exactly as today. This naturally satisfies:
   - Fixture (b) / point (3): an all-unmappable set's union is `{sentinel}` alone (every member
     contributes only the sentinel; `sort -u` collapses duplicates) -- unchanged output.
   - Fixture (a) / point (1): a mixed set's union is `{sentinel, suiteA, suiteB, ...}` -- the
     mappable members' real suites survive, the sentinel no longer suppresses them (a "floor,"
     not a "ceiling").
   - Point (3)'s other half ("a set that resolves to a suite now must resolve to the same suite
     after the change"): an all-mappable set never touches the sentinel at all, so is provably
     unaffected (no code path to it changes for that case).
2. **Audit and adapt every existing `-eq 1 && ==sentinel` call site to a "does the output
   CONTAIN the sentinel" test** -- this is a required companion change, not a second
   independent fix of the defect:
   - `verify-deploy.sh` line 1536-1539 (Gate 8 `--gate8-touched`): MUST detect "sentinel present
     anywhere in `GATE8_SUITES`" (not "array is exactly `[sentinel]`") and fall back to the full
     unnarrowed battery whenever it is, to preserve the fail-safe execution guarantee its own
     header (line 495-497) documents relying on. This file is not in this record's declared
     territory (only `suite-selection-lib.sh` and `tests/test-run-all-selection.sh` are), so the
     implementing phase should either widen this record's own file scope to include it, or file
     a same-batch companion task -- leaving it unaddressed would silently regress Gate 8 coverage
     for any touched set mixing a mapped and an unmapped path.
   - `suite-selection-lib.sh`'s own header "Usage" snippet (lines 158-165): rewrite the canonical
     example to the same "contains sentinel" test, since the current snippet's `else` branch
     would otherwise hand `run-all.sh --only` the literal token `__FULL_SWEEP__` as if it were a
     suite name.
   - `validate-artifact.sh`'s own Tier Justification block (lines 820-825): for the
     `sentinel`-claim-kind branch, "contains the sentinel and nothing else" is the correct
     "no suite covers this" test (unchanged conceptually from today, just restated as a
     contains-check). For the `suitelist`-claim-kind branch (lines 831-865), strip the sentinel
     token from `_tj_actual` before computing `_tj_missing`/`_tj_extra` -- the sentinel is not
     itself a claimable suite name, and leaving it in the comparison set would turn today's
     false-fabrication warning into a new false-under-verification warning ("additionally
     returns (`__FULL_SWEEP__`)") for the exact same honest mixed-set claim this record exists
     to stop flagging. This is the one validate-artifact.sh change genuinely required by the
     selector's new contract, and is a necessary adaptation to the changed API, not a duplicate
     fix of the defect itself -- it does not independently re-derive compositional set semantics,
     it only drops a non-claimable token from an existing comparison.
3. **State the layer-ownership ruling explicitly in the implementing commit**, per point (2) --
   this report's recommendation is (1)+(2) above (selector-layer fix, with the listed necessary
   call-site adaptations), but the formal ruling and its reasoning belong in that commit, not here.
4. **Update `tests/test-run-all-selection.sh` Case 3** (lines 146-156) to the new expected
   outcome (mixed lint-fixture + zero-ref-candidate resolves to the lint fixture's real suites,
   not pure sentinel) alongside adding the three new fixtures (a)/(b)/(c) the dispatch requires --
   leaving Case 3 unchanged would pin the old, now-incorrect behavior and the suite would fail
   honestly against its own newly-fixed subject.
5. **Reuse existing fixture-derivation conventions** rather than inventing new ones: Case 1's
   live `ZERO_REF_CANDIDATE` derivation loop for an "all-sentinel" input (fixture (b)); a
   dynamically-derived mappable path (e.g. `lint/lint-agent-contracts.sh`, already used by Case
   2) paired with a freshly-derived zero-reference candidate for the mixed case (fixture (a));
   and `test-validate-artifact.sh`'s `make_tj_fixture`/`TJ_UNMAPPED_PATH` PID-suffix pattern
   (lines 566-644) as the direct model for fixture (c)'s synthetic two-phase plan and its
   subprocess invocation of `validate-artifact.sh`.
6. **Pin the caller-facing composition-contract statement** ("ALSO WORTH PINNING" in the
   dispatch) in `suite-selection-lib.sh`'s own PUBLIC API header, immediately after the
   `suite_selection_select` entry (around line 132): one sentence stating that composing
   per-path invocations and unioning their results by hand is NOT equivalent to one multi-path
   call once the compositional fix lands (the two give the same answer when no path in the set
   is unmappable, but can legitimately differ when one is), modeled on
   `suite-resolver-lib.sh`'s own header framing of the same hazard (lines 11-17). This closes the
   authoring half of the defect the dispatch's corroboration section identifies (task 420's
   citation: an author composing per-path under-named coverage), independent of the mechanical
   half (1)+(2) above fix.

## Decisions

- **Scope confirmed**: this record's own declared territory (`suite-selection-lib.sh` and
  `tests/test-run-all-selection.sh`) is sufficient to hold the core selector-layer fix and its
  pinning fixtures, but the fix is not SAFELY completable without also touching
  `validate-artifact.sh` (the sentinel-stripping adaptation in Recommendation 2's third bullet,
  which the dispatch's own fixture (c) already requires exercising) and very likely
  `verify-deploy.sh` (Gate 8's fail-safe preservation). The implementing phase should treat the
  verify-deploy.sh adaptation as in-scope companion work, not a silently-accepted regression.
- **`suite_resolver_resolve` is NOT a substitute backend for the Tier Justification check** --
  plan-format.md's own documented scope ties the check to `suite_selection_select`'s raw output,
  and `suite_resolver_resolve` additionally folds in the explicit map and any declared backend,
  which would silently broaden what the check measures beyond this record's NON-GOALS.
- **Dependency 505 is satisfied**: already archived/[COMPLETED]; this report's own live
  measurements were taken against the post-505 library, so no further re-derivation against a
  pending upstream change is needed before planning.
- **Tasks 575 and 652 remain correctly un-edged**: 575 (`fix_ceiling_check_stopword_unit_false_
  positive`) touches a disjoint code block in validate-artifact.sh (the cross-phase ceiling
  check, not the Tier Justification block) with no dependency filed, consistent with the
  dispatch's own territory note. Task 652 (`validate_artifact_corpus_resolution`) already
  depends on this task (564) in `specs/state.json`, confirming the territory edge the dispatch
  added is correctly reflected in current state.

## Risks & Mitigations

- **Risk**: changing `suite_selection_select`'s return contract silently breaks Gate 8's
  fail-safe fallback (verify-deploy.sh), causing a narrowed run to skip real coverage for a
  genuinely-unmapped touched path mixed into the same `--gate8-touched` set. **Mitigation**:
  Recommendation 2's first bullet -- update verify-deploy.sh's detection idiom in the same
  implementation pass; add or extend a verify-deploy.sh-side regression case (or, at minimum,
  confirm via the existing Gate 8 test coverage this task's VERIFY section does not explicitly
  name) that a mixed `--gate8-touched` set still falls back to the full battery when any member
  is unmapped.
- **Risk**: the dispatch's own appended corroboration command no longer reproduces against the
  live corpus (`context/contracts/phase-closure.md` is now mappable, not sentinel-mapped),
  which could mislead an implementer trying to replay it as a smoke test. **Mitigation**: this
  report substitutes a freshly-verified live reproduction (`audit-deletion-references.sh` +
  `lint/lint-agent-contracts.sh`); logged to the issue log (class "plan premise inaccurate",
  severity minor) per the Issue Log contract.
- **Risk**: fixture (c) (added to `test-run-all-selection.sh`, which currently has no knowledge
  of `validate-artifact.sh` at all) duplicates `test-validate-artifact.sh`'s fixture-builder
  machinery rather than reusing it, creating drift between the two suites' Tier Justification
  fixture conventions. **Mitigation**: Recommendation 5 -- model fixture (c) directly on
  `make_tj_fixture`/`TJ_UNMAPPED_PATH`'s existing pattern rather than inventing a new one;
  consider (planning-phase decision) whether the two-phase synthetic-plan builder itself should
  be promoted to a shared helper if a third consumer ever needs it, deferring that promotion
  until then per this corpus's existing "second consumer is the promotion signal" convention
  (seen elsewhere in validate-artifact.sh's own coupled-surfaces reader).

## Context Extension Recommendations

- **Topic**: `suite-selection-lib.sh`'s PUBLIC API header documentation of
  `suite_selection_select`'s return contract.
- **Gap**: the header's own "Usage" example (lines 158-165) and PUBLIC API description (lines
  129-132) will both go stale the moment the selector-layer fix lands (per Recommendation 2's
  second bullet) unless updated in the same pass; there is currently no standing doc reminding a
  future editor that this header must move in lockstep with the function's return-contract.
- **Recommendation**: fold the header rewrite into this task's own implementation (not a
  separate follow-up) -- Recommendation 6 already covers the composition-contract pinning; the
  "Usage" snippet rewrite should land alongside it, in the same commit as the behavioral change,
  so the header is never observed in an inconsistent state relative to the code it documents.

## Appendix

- Search queries / commands used: `jq -r '.extensions.core.source_dir' .claude-extensions.json`;
  live `suite_selection_select`/`suite_selection_unmapped` invocations against
  `agent-system/extensions/core/scripts/lib/suite-selection-lib.sh` (sourced directly); `grep -rln
  "suite_selection_select\b"` and `grep -rln "suite-selection-lib.sh"` across
  `agent-system/extensions/core`; `jq` queries against `specs/state.json` and
  `specs/archive/state.json` for tasks 505/564/575/652; `diff -q` between source-store and
  deployed copies of the three key files; `bash tests/test-run-all-selection.sh` (36/36 baseline
  pass, confirming Case 3 currently pins the pre-fix behavior).
- References: `agent-system/extensions/core/scripts/lib/suite-selection-lib.sh`,
  `agent-system/extensions/core/scripts/validate-artifact.sh` (lines 353-376, 761-869),
  `agent-system/extensions/core/scripts/verify-deploy.sh` (lines 489-498, 1520-1548),
  `agent-system/extensions/core/scripts/lib/suite-resolver-lib.sh` (lines 1-58, 193-283),
  `agent-system/extensions/core/scripts/verify-touched.sh`,
  `agent-system/extensions/core/scripts/report-suite-coverage.sh`,
  `agent-system/extensions/core/scripts/tests/test-run-all-selection.sh` (lines 1-269),
  `agent-system/extensions/core/scripts/tests/test-validate-artifact.sh` (lines 560-691),
  `agent-system/extensions/core/context/formats/plan-format.md` (lines 450-520, 873-907),
  `specs/archive/505_suite_selection_non_core_extension_paths/summaries/01_non-core-suite-
  selection-mapping-summary.md`.
