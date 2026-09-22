# Research Report: In-Batch Deferral Should Compare Against the Admitted Set, Not the Whole Batch

**Task**: 245 - Batch admit: defer against admitted set only
**Started**: 2026-09-22
**Completed**: 2026-09-22
**Effort**: Small-to-medium (single-file jq restructuring plus one new regression test)
**Dependencies**: None
**Sources/Inputs**:
- Codebase: `agent-system/extensions/core/scripts/orchestrate-batch-admit.sh`
- Codebase: `agent-system/extensions/core/scripts/lib/file-scope-overlap.sh`
- Codebase: `agent-system/extensions/core/docs/architecture/batch-admit-schema.md`
- Codebase: `agent-system/extensions/core/scripts/orchestrate-cycle-plan.sh` (caller)
- Codebase: `agent-system/extensions/core/scripts/test-conflict-predicate.sh` (test-harness precedent)
- Codebase: `agent-system/extensions/core/context/patterns/batch-orchestration-guardrails.md`
**Artifacts**:
- path: `specs/245_batch_admit_defer_against_admitted_set_only/reports/01_admitted_set_only_defer.md`
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- The defect is real and precisely located: `orchestrate-batch-admit.sh`'s `in_batch` deferral
  branch (the `select($scope_kind == "cross_batch" or $other_num < $c)` clause, around line 614
  of the current file, feeding the `$overlaps`/`$hit` computation at lines 599-627) tests a
  candidate against **any** lower-numbered same-invocation candidate that overlaps in
  `file_scope`, without checking whether that lower-numbered candidate's own verdict this cycle
  is `admit` or `defer`. A candidate that only overlaps a peer that is *itself deferring this
  cycle* pays the same one-cycle wait as a candidate that overlaps a peer that is actually
  dispatching — a pure false positive relative to the concurrent-write hazard the check exists to
  prevent (no dispatch of the deferred peer happens this cycle, so there is nothing to
  concurrently write against).
- The fix is a genuine algorithm change, not a schema change: greedily walk candidates in
  ascending `project_number` order, and for the `in_batch` collision test only, compare against
  the running set of candidates *already decided `admit`* in that same ascending walk — not
  against the raw `$cands` membership list. `cross_batch`, `session_active`, and
  self-modification checks are unaffected (none of them depend on which in-batch peers are
  admitted).
- This requires restructuring the jq program from an order-independent `$cands[] as $c | ...`
  map into an explicit `reduce` (or equivalent fold) over `($cands | sort)`, threading a
  `$admitted_so_far` set forward, while still emitting NDJSON in the original **input** argument
  order (a documented, separate contract — see "Output ordering" below).
- Recommend **no `$schema` version bump**. Applying the same classification test the schema doc's
  own Version History already uses (self-modification tie-breaker entry): this change reassigns
  which of the two *already-existing* `file_scope_collision` verdict shapes (`admit` vs.
  `defer` with `defer_reason: "file_scope_collision"`, `collision_scope: "in_batch"`) a candidate
  lands in, using criteria no consumer needs to inspect (consumers already branch on `decision` /
  `defer_reason` / `collision_scope`, never on *why* a lower-numbered peer was or was not
  admitted). No field is added, removed, or repurposed.
- A regression test reproducing the exact reported chain (A admitted, C defers on A, D overlaps
  only C and should admit) does not yet exist. The closest existing precedent,
  `scripts/test-conflict-predicate.sh`, is a good structural model (isolated temp root, byte-for-
  byte script copies, fixture `state.json`) but does not itself cover multi-candidate in-batch
  chains; a new dedicated suite or an extension of that file is needed.

## Context & Scope

Task scope, per the dispatch: change only the `in_batch` deferral comparison set inside
`orchestrate-batch-admit.sh` so it compares each candidate against the set of candidates *actually
admitted this cycle*, computed greedily in ascending `project_number` order, preserving
determinism (same input -> same admitted set) and leaving `cross_batch` semantics (the v5
evidence-gating narrowing) untouched. Add a regression test reproducing the reported A/C/D chain.
Out of scope: empty/absent `file_scope` admission posture (a separate topic per the dispatch).

## Findings

### Codebase Patterns

**Exact defect location** — `agent-system/extensions/core/scripts/orchestrate-batch-admit.sh`,
inside the big `jq -n -c` program, in the branch reached once a candidate is neither an
early-exit admit nor self-modifying (roughly lines 598-627 of the current file):

```jq
(
  [
    $all[] | . as $t | select(
      ($t.project_number != $c) and
      ((($t.status // "") | is_terminal) | not) and
      (($c_deps | index($t.project_number)) == null) and
      ((($t.dependencies // []) | index($c)) == null)
    )
  ] | sort_by(.project_number)
) as $comparison_set |
(
  [
    $comparison_set[] as $other |
    ($other.project_number) as $other_num |
    ($cands | index($other_num)) as $in_batch_idx |
    (if $in_batch_idx == null then "cross_batch" else "in_batch" end) as $scope_kind |
    select($scope_kind == "cross_batch" or $other_num < $c) |
    scopes_overlap_first($c_scope; ($other.file_scope // [])) as $ov_path |
    select($ov_path != null and $ov_path != "") |
    { other_num: $other_num, other_status: ..., ov_path: $ov_path,
      scope_kind: $scope_kind, in_flight: (...) }
  ]
) as $overlaps |
($overlaps | map(select(.scope_kind == "in_batch" or .in_flight)) | first) as $hit |
...
```

`($cands | index($other_num)) as $in_batch_idx` only tests **membership** in the positional
argument list — it says nothing about whether `$other_num`'s own verdict, computed independently
in this same invocation, is `admit` or `defer`. Because every `$c` in `$cands[]` is evaluated by
an independent map over the *same* `$comparison_set`/`$overlaps` derivation, there is no notion
of "processing order" or "what has been decided so far" anywhere in the current program — jq's
`$cands[] as $c | ...` construct is an order-independent generator, not a fold.

This matches the dispatch's observed defect exactly: task D (independent of A and B) deferred
against task C (project_number lower than D, `overlapping_path` at `docs/README.md`) even though
C itself deferred against A this same cycle and therefore never dispatched. C's own `decision` at
verdict-computation time is irrelevant to D's branch — the jq program never looks at it, because
it is never materialized as an intermediate value at all; every candidate's verdict object is
built from scratch against the static `$comparison_set`.

**The deferral-direction rule (already correct in spirit, wrong in scope)** — the file's own
header comment (lines 260-266) states the intended semantic precisely:

> in_batch ... the candidate defers ONLY against a task with a LOWER project_number. A
> higher-numbered in-batch task is the one that defers instead (it will see this candidate as its
> own lower-numbered collision when ITS verdict is computed).

This sentence already assumes a *conceptual* ordering ("the one that defers instead") but the
actual jq implementation never threads any such ordering through — "defers instead" is asserted
by the comment, not computed by the program. The fix task's deliverable is to make the
implementation match this already-stated intent, narrowed further: not just "defers instead of
the higher-numbered one" but "only a currently-*admitted* lower-numbered task blocks; a deferred
lower-numbered task does not."

**Determinism requirement already documented and reusable** — the file's "Determinism" section
(lines 281-286) already commits to ascending `project_number` visiting order and first-match-wins
for the comparison-set scan. The self-modification tie-breaker (`$designated_sm_candidate`,
lines 523-544) already demonstrates the exact pattern needed: it pre-computes, over the *whole*
`$cands` set independent of per-candidate branch order, "the lowest task number among candidates
matching predicate X" via `map(...) | map(select(. != null)) | if length > 0 then min else null
end`. That pattern is a **global**, order-independent reduction (it does not depend on any
candidate's *decision*, only on its own `file_scope`), so it cannot be reused directly for this
fix — the admitted-set computation is inherently sequential (candidate N's admittedness among
*peers* can depend on candidate N-1's admittedness, which can depend on N-2's, etc., when several
lower-numbered peers all mutually overlap). This is the key structural difference from every
existing "first match wins" reduction already in the file: those are order-independent
(commutative) reductions; this one is not.

**`--invocation-count` and `--phase-map` are orthogonal to this fix.** Both are already resolved
before the per-candidate branch runs (`$inv_count`, `$phase_group` per candidate) and neither
depends on in-batch collision outcomes. The self-modification branch's own greedy admitted-set
notion (the tie-breaker) is unaffected by this change and vice versa — a self-modifying candidate
never reaches the collision scan at all (short-circuit precedence, "Precedence (D4)" comment,
lines 194-207), so the two order-dependent mechanisms (self-mod tie-breaker, in-batch admitted-set
walk) never interact.

**Output ordering is a separate, must-preserve contract.** Line 107 and the schema doc's
"Invocation Contract" section both state verdicts print "one compact JSON object per candidate...
in input order" — i.e., the order the caller passed `<task_number>` arguments, **not** ascending
numeric order. `orchestrate-cycle-plan.sh` passes `"${eligible_tasks[@]}"` (line 1524), whose
order is itself whatever `eligible_tasks` accumulated in (state.json iteration order, not
necessarily ascending `project_number` — see `agent-system/extensions/core/scripts/orchestrate-cycle-plan.sh:1318-1397`).
The greedy admitted-set walk must therefore process candidates in **ascending `project_number`
order** to compute decisions correctly, but must **emit** NDJSON rows in the **original argument
order** the caller supplied. These are two independent orderings and the fix must not conflate
them (an accidental switch to ascending-order output would be an unannounced, consumer-visible
breaking change, since `orchestrate-cycle-plan.sh`'s consumption loop at lines 1539-1583 reads
rows via `while IFS= read -r row` and keys off each row's own `task_number` field into an
associative array — so it is actually insensitive to row order today, but two other consumers
(`orchestrate-predispatch-review.sh`, the dry-run reporter) may not be; preserving input order
is the documented contract regardless of whether every consumer currently depends on it).

### Recommendations

**Algorithm.** Replace the order-independent `$cands[] as $c | ...` top-level generator (or at
least the in-batch portion of it) with a `reduce` over candidates sorted ascending by
`project_number`, threading forward an accumulator that records, for each already-processed
candidate, its final `decision`. Concretely (sketch, not final code — the planner/implementer
should verify field-by-field against the existing branches, especially self-modification's
short-circuit and the cross_batch/session_active precedence chain, which must stay entirely
unchanged):

```jq
($cands | sort) as $ordered |
reduce $ordered[] as $c
  ( {results: {}, order: []};  # results: {"<task_number>": <verdict object>}
    . as $acc |
    ($acc.results) as $admitted_lookup |     # map of already-decided candidates -> verdict
    # ... existing self-mod / early-exit branches unchanged, they never consult $admitted_lookup ...
    # in-batch collision test becomes:
    #   select($scope_kind == "cross_batch" or
    #          ($other_num < $c and
    #           ($admitted_lookup["\($other_num)"].decision // "admit") == "admit"))
    # (a lower-numbered peer NOT YET in $admitted_lookup at all cannot happen once candidates are
    # walked in ascending order and $cands has no duplicates outside this candidate's own set --
    # every strictly-lower candidate has already been decided by the time $c is processed.)
    ... build $verdict ...
    | .results[($c|tostring)] = $verdict | .order += [$c]
  )
| .results as $by_num |
# re-emit in the ORIGINAL caller argument order, not ascending order:
$candidates[] as $orig | $by_num[($orig|tostring)]
```

Key points this sketch is trying to capture for the implementer:

1. **`sort` once, fold once.** `$cands` may contain duplicates (the header comment explicitly
   allows duplicate positional arguments and preserves them in output). `sort` on an array with
   duplicates is fine for the fold (each occurrence is processed independently, and a duplicate
   task number folded twice will simply look itself up and find its own already-decided verdict
   from the first occurrence — this is a pre-existing edge case, not introduced by this fix, and
   worth a one-line note in the implementation rather than new handling).
2. **A lower-numbered peer might not be present in `$admitted_lookup` for a reason other than
   "not yet processed."** Once folding strictly ascending, every distinct lower `project_number`
   in `$cands` *has* been processed by the time `$c` is reached, so absence from the lookup can
   only mean "this `$other_num` was never a candidate at all" — which is impossible inside the
   `in_batch` branch by construction (`$in_batch_idx != null` is exactly the guard that put it in
   this branch). So the `// "admit"` fallback in the sketch above is defensive, not load-bearing;
   the implementer should decide whether to keep it as a belt-and-suspenders guard or assert
   non-null and treat a lookup miss as an internal-invariant violation (the latter is arguably
   more honest given the "verdicts are data, never crash mid-batch" posture the rest of the
   script holds itself to — the assert should still degrade to *admit*, per this script's
   existing "when in doubt, admit rather than silently block forever" posture used for unknown
   task numbers and degraded critical-path data elsewhere in the file).
3. **`cross_batch`, `session_active`, and self-modification are unaffected** — they must be
   computed exactly as today for every candidate, independent of the new admitted-set state. Only
   the boolean feeding into `$hit`'s `in_batch` disjunct changes.
4. **Cascading defers must still converge in one cycle where possible.** If D only overlaps C, and
   C itself only overlaps a *cross_batch* in-flight task E (not another in-batch candidate), then
   C still defers (cross_batch collision, unaffected by this fix) and D should now admit (since C
   is not in the admitted set) — this is exactly the reported scenario and the deliverable's
   worked example. If instead C's defer is itself caused by an *earlier* in-batch candidate B
   (B admitted, C defers on B, D only overlaps C), the same walk naturally produces "D admits"
   too, because C is correctly absent from `$admitted_lookup` regardless of *why* C deferred.
   The fix is uniform across all three `defer_reason` values that can keep a lower-numbered
   in-batch peer out of the admitted set — the implementer should make sure the test suite (see
   below) covers at least the `file_scope_collision`-caused-defer chain (the reported case) and
   ideally also a `self_modifying`-caused defer chain, since both are equally valid ways for a
   lower-numbered in-batch candidate to end up NOT admitted this cycle.

**Version/schema impact.** No `$schema` bump. Follow the precedent already recorded in
`docs/architecture/batch-admit-schema.md`'s "Self-modification tie-breaker and `--phase-map` —
NOT a version bump" entry: this change reassigns which of two pre-existing verdict shapes a
candidate lands in, using an internal criterion no consumer inspects. Update the schema doc's
"Deferral-Direction Rule and Caller Guidance" `in_batch` bullet and the "Determinism" section to
state the narrowed rule explicitly (a lower-numbered peer blocks only when it is *itself admitted*
this cycle), and add a short "admitted-set-only narrowing" entry to "Version History" describing
the behavior change without a version bump, mirroring the tie-breaker entry's structure and
justification. `orchestrate-cycle-plan.sh` and the other two `defer_reason`-branching consumers
(`orchestrate-dry-run-report.sh`, `orchestrate-predispatch-review.sh`) need **no code changes** —
they already branch on `decision`/`defer_reason`/`collision_scope`, never on which lower-numbered
peer specifically caused a defer versus whether that peer was itself admitted.

**Test placement and shape.** No test file for this script exists yet under `scripts/tests/`
(confirmed via search — only `scripts/test-conflict-predicate.sh`,
`scripts/test-four-tier-conflict.sh`, and `scripts/test-conflict-predicate.sh` at the top level of
`scripts/`, none of them multi-candidate in-batch chain tests). Two viable placements, either
satisfies the dispatch:
- **New `scripts/tests/test-orchestrate-batch-admit.sh`** — a dedicated suite. Recommended if the
  team wants admit-predicate tests to live under `scripts/tests/` going forward (this would be
  the first).
- **Extend `scripts/test-conflict-predicate.sh`** — reuses its existing isolated-temp-root harness
  (byte-for-byte copies of `task-lock.sh`, `orchestrate-batch-admit.sh`,
  `deploy-root-guard.sh`, `lib/file-scope-overlap.sh`, `lib/common.sh`,
  `lib/task-lookup-lib.sh` into `$TMPROOT/.claude/scripts/`, plus a fixture `state.json`) with
  minimal new plumbing, since the harness is already wired to invoke
  `orchestrate-batch-admit.sh` directly.

Either way, the harness pattern from `test-conflict-predicate.sh` (isolated temp root satisfying
`deploy-root-guard.sh`'s two-levels-under-root check, `pass`/`fail`/`info` helpers, `trap cleanup
EXIT`) should be reused rather than re-derived — it is the established local convention for
testing this exact script and its siblings (`test-session-registry.sh`, `test-task-lock-reap.sh`
are named as its own precedents).

**Minimum regression scenario to encode** (directly reproduces the dispatch's observed chain):
four candidates A < B < C < D, none terminal, none self-modifying, no `dependencies[]` edges.
`file_scope` declared so that:
- A and C overlap (e.g., both declare `docs/ci.md` or a shared directory).
- C and D overlap on a *different* path (e.g., `docs/README.md`), and D does **not** overlap A or
  B at all.
- B is scope-disjoint from everyone (present only to match the reported "two tasks admitted"
  shape faithfully, though it is not load-bearing for the assertion).

Invoke `orchestrate-batch-admit.sh --invocation-count 4 A B C D` (order matching the reported
scenario) and assert, from the NDJSON:
- A: `decision == "admit"`.
- C: `decision == "defer"`, `defer_reason == "file_scope_collision"`,
  `collision_scope == "in_batch"`, `colliding_task_number == A`.
- D: `decision == "admit"` (the regression assertion — pre-fix, D incorrectly deferred against
  C here) — with the code as it stands today, running this exact scenario against the
  *unmodified* script should reproduce a `defer` for D, confirming the test fails before the fix
  and passes after.
- (Optional second case, since the fix is symmetric across defer reasons) A self-modifying
  variant: A is a designated self-modifying admit, B is a co-dispatched self-modifying candidate
  that defers on the tie-breaker, C overlaps B's (unrelated, ordinary) `file_scope` only — assert
  C admits despite B being lower-numbered and in-batch, because B did not admit.

## Decisions

- No `$schema` version bump for this change (see "Version/schema impact" above) — treat as an
  algorithm correction analogous to the documented self-modification tie-breaker precedent.
- The fix is scoped to `orchestrate-batch-admit.sh`'s `in_batch` branch of the collision scan
  only; `cross_batch`, `session_active`, and self-modification logic are unchanged.
- Reuse `test-conflict-predicate.sh`'s isolated-temp-root harness pattern for the new regression
  test rather than deriving a new harness convention.

## Risks & Mitigations

- **Risk**: naive reduce-based restructuring accidentally changes NDJSON output order from
  caller-argument order to ascending-numeric order. **Mitigation**: fold over `sort`ed candidates
  to compute decisions, but re-emit by iterating the *original* `$candidates` array (or an
  order-preserving structure) at the end, as sketched above; add an explicit test asserting output
  row order matches input argument order when arguments are passed out of ascending order (e.g.
  `D C A B` as positional args) — this is not covered by the minimum scenario above and should be
  a distinct assertion.
- **Risk**: performance regression from turning an O(candidates x comparison_set) independent map
  into a sequential fold. **Mitigation**: negligible in practice — batch sizes are bounded by
  `MAX_CYCLES`/wave sizes already small enough for the existing full comparison-set scan per
  candidate; a fold over the same candidate count adds no new asymptotic cost, only a threading
  dependency.
- **Risk**: duplicate positional task numbers (explicitly permitted by the header comment)
  interacting oddly with the admitted-set lookup. **Mitigation**: call out explicitly in the
  implementation as a pre-existing edge case (see Recommendations point 1) rather than silently
  changing duplicate-handling semantics; add a one-line note in the implementer's plan rather than
  new test coverage unless the planner judges it worth a dedicated case.
- **Risk**: the schema doc's `in_batch` deferral-direction prose ("the candidate defers ONLY
  against a task with a LOWER project_number... a higher-numbered in-batch task is the one that
  defers instead") is only partially accurate post-fix — a higher-numbered task no longer
  unconditionally "defers instead"; it defers only if the lower-numbered one is itself admitted.
  **Mitigation**: update that prose alongside the code change (see Recommendations,
  "Version/schema impact") so the documented rule and the implemented rule stay in sync — this
  is documentation debt introduced by the fix, not a runtime risk, but should not be left stale.

## Context Extension Recommendations

- **Topic**: In-batch admitted-set-only deferral algorithm.
- **Gap**: `docs/architecture/batch-admit-schema.md`'s "Deferral-Direction Rule and Caller
  Guidance" and "Determinism" sections currently describe the pre-fix (whole-batch-membership)
  `in_batch` rule as if it were already admitted-set-aware ("the one that defers instead" implies
  but does not state the admitted-set narrowing).
- **Recommendation**: once implemented, add a "v5 admitted-set-only narrowing (still v5, no
  version bump)" subsection to that document's Version History, modeled directly on the existing
  "Self-modification tie-breaker and `--phase-map` — NOT a version bump" entry's structure and
  justification, and update the `in_batch` bullet's wording accordingly.

## Appendix

- Files read in full or in relevant part: `orchestrate-batch-admit.sh` (full),
  `lib/file-scope-overlap.sh` (full), `docs/architecture/batch-admit-schema.md` (full),
  `orchestrate-cycle-plan.sh` (admission-consumption section, lines ~1490-1630),
  `test-conflict-predicate.sh` (header/harness section), `batch-orchestration-guardrails.md`
  (grep for `in_batch`/`admitted set`/`greedy`/`ascending`).
- Searches: `grep -rn "orchestrate-batch-admit.sh"` across `agent-system/extensions/core` to
  enumerate every caller/consumer/reference; `find ... -iname "*batch-admit*"` to confirm no
  existing dedicated test file.
- No web research was needed — this is a pure single-repo jq/bash algorithm defect with no
  external library or API surface involved.
