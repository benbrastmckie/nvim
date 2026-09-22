# Implementation Plan: Batch admit defers against the admitted set only

- **Task**: 245 - Batch admit: defer against admitted set only
- **Status**: [IMPLEMENTING]
- **Effort**: 3.5 hours
- **Dependencies**: None
- **Research Inputs**: `specs/245_batch_admit_defer_against_admitted_set_only/reports/01_admitted_set_only_defer.md`
- **Artifacts**: plans/01_admitted-set-only-defer.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

`scripts/orchestrate-batch-admit.sh`'s `in_batch` deferral branch tests a candidate against any
lower-numbered task that merely appears in this invocation's positional argument list, without
checking whether that lower-numbered peer is itself being admitted this cycle. A candidate whose
only overlap is with a peer that is *also deferring* therefore pays a needless one-cycle wait —
no dispatch of the deferred peer happens, so there is no concurrent-write hazard to guard
against. The fix converts the jq program's order-independent `$cands[] as $c | ...` generator
into an explicit `reduce` over candidates sorted ascending by `project_number`, threading a
running admitted-set lookup forward so the `in_batch` collision test compares only against peers
already decided `admit`. Done when the reduce lands, NDJSON output still emits in caller-argument
order, `cross_batch`/`session_active`/self-modification semantics are bit-for-bit unchanged, a new
regression suite reproduces the A/C/D chain (red before the fix, green after), and the schema doc
and in-file header prose state the narrowed rule.

### Research Integration

The research report fixes every substantive decision this plan implements:

- **Exact defect site**: the `select($scope_kind == "cross_batch" or $other_num < $c)` clause and
  the `$overlaps`/`$hit` derivation it feeds, inside the single large `jq -n -c` program.
  `($cands | index($other_num))` tests *argument-list membership* only and never consults the
  peer's own verdict, which the current program never materializes as an intermediate value.
- **Why the existing reductions cannot be reused**: `$designated_sm_candidate` is an
  order-*independent* (commutative) global reduction. The admitted-set walk is inherently
  sequential — candidate N's admittedness can depend on N-1's, which can depend on N-2's — so it
  requires a genuine fold, not another `map | min`.
- **Two orderings must not be conflated**: decisions are computed in ascending `project_number`
  order; NDJSON rows must still be emitted in the *original caller argument order*, which is a
  documented contract (header comment plus the schema doc's Invocation Contract) independent of
  whether every consumer happens to depend on it today.
- **No `$schema` version bump**: this reassigns which of two pre-existing verdict shapes a
  candidate lands in, using an internal criterion no consumer inspects — the same classification
  the schema doc's own "Self-modification tie-breaker and `--phase-map` — NOT a version bump"
  Version History entry already applies.
- **Consumers need no code change**: `orchestrate-cycle-plan.sh`, `orchestrate-dry-run-report.sh`,
  and `orchestrate-predispatch-review.sh` branch on `decision`/`defer_reason`/`collision_scope`
  only.
- **Test harness precedent**: `scripts/test-conflict-predicate.sh`'s isolated-temp-root pattern
  (byte-for-byte script copies into `$TMPROOT/.claude/scripts/`, fixture `state.json`,
  `pass`/`fail`/`info` helpers, `trap cleanup EXIT`) is the established local convention and is
  reused rather than re-derived.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No `roadmap_path` was supplied in the dispatch and `specs/ROADMAP.md` does not exist. No roadmap
phases are included.

## Goals & Non-Goals

**Goals**:
- Compute `in_batch` deferral against the set of candidates actually admitted this cycle,
  determined greedily in ascending `project_number` order.
- Preserve determinism: identical input produces an identical admitted set.
- Preserve NDJSON emission in caller-argument order, including when arguments are passed out of
  ascending order.
- Leave `cross_batch` (v5 evidence-gating), `session_active`, `idle_overlap_advisory`, and the
  self-modification branch (including the `$designated_sm_candidate` tie-breaker and the
  `--phase-map` research/plan exemption) semantically unchanged.
- Keep `defer_reason: "file_scope_collision"` verdicts naming the specific admitted task that
  blocked the candidate via `colliding_task_number` / `overlapping_path` / `reason`.
- Add a regression suite reproducing the observed chain: A admitted, C defers on A, D overlaps
  only C and is therefore admitted.

**Non-Goals**:
- Empty or absent `file_scope` admission posture (owned by the file-scope-lifecycle topic tasks).
- Any `$schema` version bump or verdict field addition, removal, or repurposing.
- Changes to `orchestrate-cycle-plan.sh` or any other verdict consumer.
- Changing duplicate-positional-argument handling (a pre-existing, explicitly permitted edge case).
- Editing `.claude/**` — the source store `agent-system/extensions/core/**` is the sole edit
  target; `.claude/` is a regenerated deploy artifact.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Reduce restructuring silently flips NDJSON output from caller-argument order to ascending-numeric order | H | M | Fold over sorted candidates to compute a `{task_number_string: verdict}` map, then re-emit by iterating the original `$candidates` array. Phase 1 encodes a dedicated out-of-order-argument assertion (arguments `D C A B`) that fails on any such flip. |
| Restructuring perturbs `cross_batch` / `session_active` / self-modification branches while moving code into the fold | H | M | Move branch bodies verbatim; only the `select(...)` predicate feeding `$overlaps` changes. Phase 4 re-runs `test-conflict-predicate.sh`, which already pins the v4/v5 session and corroboration behavior. |
| Duplicate positional task numbers interact oddly with the admitted-set lookup (a duplicate looks itself up and finds its own first-occurrence verdict) | L | M | Pre-existing edge case, deliberately not changed. Record it as an in-file comment at the lookup site rather than adding new handling. |
| An `$admitted_lookup` miss inside the `in_batch` branch is treated as a crash rather than degrading | M | L | Impossible by construction once folding strictly ascending (`$in_batch_idx != null` is the guard that reached the branch), but keep a defensive fallback that degrades to *admit*, matching the script's existing "when in doubt, admit rather than silently block forever" posture. |
| Schema-doc prose ("a higher-numbered in-batch task is the one that defers instead") is left stale and contradicts the implemented rule | M | M | Phase 3 updates the Deferral-Direction bullet, the Determinism section, the in-file header comment, and adds a Version History entry — documentation debt introduced by this fix, closed in the same task. |
| Concurrent sibling dispatches on the shared working tree touch adjacent files | M | L | Declared sibling `file_scope` sets do not intersect this task's three files. Still: re-read each file immediately before editing, stage only this task's own hunks with an explicit file list (never `git add -A`, a directory, or a glob), and never run `git-snapshot.sh` in its reverting default mode. |
| Performance regression from a sequential fold replacing an independent map | L | L | No new asymptotic cost — same candidate count, same comparison-set scan, plus a threading dependency. Batch sizes are already bounded by wave sizes. No mitigation work required. |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2 | 1 |
| 3 | 3 | 2 |
| 4 | 4 | 2, 3 |

Phases within the same wave can execute in parallel.

### Phase 1: Regression suite with a confirmed red baseline [COMPLETED]

- **Goal:** Add a dedicated test suite that reproduces the observed A/C/D chain and *fails on the
  unmodified script*, establishing the red baseline the fix must turn green.
- **Tasks:**
  - [x] Create `agent-system/extensions/core/scripts/tests/test-orchestrate-batch-admit.sh`,
        modeled on `scripts/test-conflict-predicate.sh`'s harness: `set -uo pipefail`, colored
        `pass`/`fail`/`info` helpers, `PASSED`/`FAILED` counters, `mktemp -d` temp root,
        `trap cleanup EXIT`, and a required-files preflight loop. *(completed)*
  - [x] Build the isolated temp root satisfying `deploy-root-guard.sh`'s "two levels under root"
        check: copy `orchestrate-batch-admit.sh`, `deploy-root-guard.sh`,
        `lib/file-scope-overlap.sh`, `lib/common.sh`, `lib/task-lookup-lib.sh`, and `task-lock.sh`
        byte-for-byte into `$TMPROOT/.claude/scripts/` (and `lib/`); `chmod +x` the invoked
        scripts. Note that the suite lives under `scripts/tests/`, so the copy source is
        `$SCRIPT_DIR/..`, not `$SCRIPT_DIR` — adjust every path from the flat-suite precedent.
        *(completed)*
  - [x] Write a fixture `$TMPROOT/specs/state.json` with four non-terminal, non-self-modifying
        `active_projects` entries A < B < C < D, no `dependencies[]` edges, and `file_scope` such
        that: A and C share one path; C and D share a *different* path; D overlaps neither A nor
        B; B is scope-disjoint from all three. *(completed: A=101 B=102 C=103 D=104)*
  - [x] Case 1 (the reported chain): invoke
        `orchestrate-batch-admit.sh --invocation-count 4 A B C D` and assert from the NDJSON —
        A `decision == "admit"`; C `decision == "defer"` with
        `defer_reason == "file_scope_collision"`, `collision_scope == "in_batch"`,
        `colliding_task_number == A`; D `decision == "admit"`. *(completed)*
  - [x] Case 2 (output-ordering contract, distinct assertion): invoke with positional arguments
        in non-ascending order `D C A B` and assert the emitted `task_number` sequence is exactly
        `D, C, A, B`. *(completed)*
  - [x] Case 3 (symmetry across defer reasons, optional but recommended): a self-modifying
        variant — A is the designated self-modifying admit, B a co-dispatched self-modifying
        candidate that defers on the tie-breaker, C overlaps only B's ordinary `file_scope`;
        assert C admits despite B being lower-numbered and in-batch. *(completed)*
  - [x] `chmod +x` the new suite (`run-all.sh` reports a lost exec bit as a loud `[SKIP]`, so a
        missing bit would produce a false green). *(completed)*
  - [x] Run the suite against the **unmodified** script and record the failure: Case 1's D
        assertion must FAIL (D currently defers on C). Cases 2 and 3 should pass or fail as
        observed; capture the actual output verbatim for the phase's completion record.
        *(completed: Case 1 FAILED — D deferred on C (colliding_task_number 103); Case 2 PASSED;
        Case 3 FAILED — C_sm deferred on B_sm (colliding_task_number 206). Suite exited 1, 1
        passed / 2 failed — the expected red baseline.)*
- **Timing:** 1 hour
- **Depends on:** none
- **Verification Tier:** local
- **Commit Mode:** per-substep
- **Scope Hypothesis:** This phase asserts exactly one new file
  (`scripts/tests/test-orchestrate-batch-admit.sh`) and zero modifications to existing files.
  Confirm at implementation time with `git status --short` before committing: any second modified
  path means the harness copy-source paths were mis-adapted from the flat-suite precedent and
  something outside the intended scope was touched.
- **Files to modify**:
  - `agent-system/extensions/core/scripts/tests/test-orchestrate-batch-admit.sh` - new isolated
    temp-root regression suite (created)
- **Verification**:
  - `bash agent-system/extensions/core/scripts/tests/test-orchestrate-batch-admit.sh` runs to
    completion (no harness error, no `ERROR: expected ... alongside this script`).
  - Case 1's D assertion reports `[FAIL]` against the unmodified script — the red baseline. A
    green Case 1 here means the test does not actually reproduce the defect and must be corrected
    before Phase 2 begins.
  - The suite exits 1 (not 0) at this phase's close, and that is the expected, recorded outcome.

---

### Phase 2: Fold candidates into an admitted-set-aware greedy walk [COMPLETED]

- **Goal:** Replace the order-independent top-level generator with a `reduce` over ascending-sorted
  candidates, threading a running admitted-set lookup that narrows the `in_batch` collision test,
  while re-emitting NDJSON in caller-argument order.
- **Tasks:**
  - [x] Re-read `agent-system/extensions/core/scripts/orchestrate-batch-admit.sh` immediately
        before editing (concurrent siblings are dispatching on this working tree). *(completed)*
  - [x] Restructure the jq program: keep every `--argjson`/`--arg` binding and every `def` intact;
        keep `$designated_sm_candidate` computed exactly as today (a global, order-independent
        reduction over the full `$cands` set, unaffected by and not interacting with the new walk
        — a self-modifying candidate short-circuits before the collision scan and never reaches it).
        *(completed)*
  - [x] Replace `$cands[] as $c | ...` with
        `reduce ($cands | sort)[] as $c ({results: {}}; ...)`, accumulating each candidate's
        finished verdict object at `.results[($c|tostring)]`. *(completed)*
  - [x] Move every existing branch body into the fold **verbatim**: the four early-exit admits
        (unknown task, terminal status, empty `file_scope`, and the non-self-mod path's
        precedence), the self-modification branch with its `--phase-map` research/plan exemption
        and tie-breaker defer, the `$comparison_set` derivation, `$idle_overlap` /
        `$idle_advisory_frag`, `session_contention`, `$session_corroborates` /
        `$corroborated_by`, and both terminal verdict shapes. Only one predicate changes.
        *(completed: verified by end-to-end git diff read — every branch body hunk is a pure
        indentation shift, no key added/removed)*
  - [x] Narrow the single changed predicate. The `in_batch` disjunct of
        `select($scope_kind == "cross_batch" or $other_num < $c)` becomes: `cross_batch`
        unchanged, or (`$other_num < $c` **and** that peer's already-recorded decision in the
        accumulator is `"admit"`). Keep a defensive fallback that treats a lookup miss as
        *admit-the-candidate* (i.e. does not block), matching the script's existing degrade-to-admit
        posture; add a one-line comment stating the miss is unreachable by construction because
        `$in_batch_idx != null` is exactly the guard that reached this branch and every strictly
        lower candidate has already been folded. *(completed)*
  - [x] Add a one-line comment at the lookup site recording the duplicate-positional-argument
        edge case: a duplicate task number folded twice looks itself up and finds its own
        first-occurrence verdict. Pre-existing behavior, deliberately unchanged. *(completed)*
  - [x] Re-emit in caller-argument order: after the fold, bind `.results` and iterate the original
        `$candidates` array (`$candidates[] as $orig | $by_num[($orig|tostring)]`), never the
        sorted array. *(completed: re-emits via `$cands[] as $orig | ($folded.results[($orig|tostring)])`,
        `$cands` being the original, unsorted `--argjson candidates` binding)*
  - [x] Update the `# Determinism:` header comment block to state the ascending-order greedy walk
        and the admitted-set narrowing (the deeper prose rewrite is Phase 3; this is the minimum
        needed to keep the code and its adjacent comment consistent at commit time). *(completed)*
  - [x] Run the Phase 1 suite: Case 1 must now be fully green, Case 2 must still be green.
        *(completed: all 3 cases green, 3 passed / 0 failed)*
- **Timing:** 1.25 hours
- **Depends on:** 1
- **Verification Tier:** full
- **Commit Mode:** per-substep
- **Scope Hypothesis:** This phase asserts exactly one modified file
  (`scripts/orchestrate-batch-admit.sh`), one changed `select(...)` predicate, and zero changes to
  the verdict schema's field set. Confirm at implementation time by reading
  `git diff -- agent-system/extensions/core/scripts/orchestrate-batch-admit.sh` end to end before
  committing: any hunk touching a verdict object's key set, or any branch body whose semantics
  changed beyond re-indentation into the fold, falsifies the hypothesis and must be reverted to
  verbatim before the phase closes.
- **Files to modify**:
  - `agent-system/extensions/core/scripts/orchestrate-batch-admit.sh` - convert the jq program's
    top-level generator to a `reduce` over ascending-sorted candidates; narrow the `in_batch`
    collision predicate to admitted peers only; re-emit NDJSON in original argument order
- **Verification**:
  - `bash -n agent-system/extensions/core/scripts/orchestrate-batch-admit.sh` (syntax).
  - `bash agent-system/extensions/core/scripts/tests/test-orchestrate-batch-admit.sh` exits 0 with
    Cases 1 and 2 green (and Case 3 green if encoded).
  - `bash agent-system/extensions/core/scripts/test-conflict-predicate.sh` exits 0 — no regression
    in the v4/v5 `session_active` / `corroborated_by` behavior.
  - `git diff` confirms no verdict field was added, removed, or repurposed and `$schema` still
    reads `orchestrate-batch-admit-v5`.

---

### Phase 3: Bring the documented rule into sync with the implemented rule [COMPLETED]

- **Goal:** Update the schema document and the script's own header prose so the stated
  deferral-direction rule matches the narrowed, admitted-set-only behavior, without a version bump.
- **Tasks:**
  - [x] Re-read `agent-system/extensions/core/docs/architecture/batch-admit-schema.md` before
        editing. *(completed)*
  - [x] Update the `in_batch` bullet under `## Deferral-Direction Rule and Caller Guidance`: a
        lower-numbered in-batch peer blocks the candidate **only when that peer is itself admitted
        this cycle**. Remove or qualify the now-inaccurate "a higher-numbered in-batch task is the
        one that defers instead" phrasing, which post-fix holds only when the lower-numbered task
        actually admits. *(completed; also fixed two downstream stale claims found during the
        grep pass: the `idle_overlap_advisory` field row's "every in_batch member blocks
        unconditionally" reasoning, and the v4-to-v5 Version History entry's "in_batch collision
        behavior is completely unaffected" claim, via a forward-pointing footnote that preserves
        that entry's own historical scope)*
  - [x] Update the Determinism prose to describe the greedy ascending-`project_number` walk over
        candidates, the running admitted set it threads, and the fact that decision order and
        emission order are two independent orderings (emission stays caller-argument order).
        *(completed: added a "Two independent orderings" paragraph under Invocation Contract)*
  - [x] Add a `## Version History` entry — "admitted-set-only in-batch narrowing (still v5, no
        version bump)" — modeled field-for-field on the existing "Self-modification tie-breaker and
        `--phase-map` — NOT a version bump" entry's structure and justification: no field added,
        removed, or repurposed; the change reassigns which of two pre-existing verdict shapes a
        candidate lands in, on an internal criterion no consumer inspects. *(completed)*
  - [x] Apply the same narrowing to the corresponding in-file header comment block in
        `orchestrate-batch-admit.sh` (the "Deferral-direction rule for file_scope_collision"
        section) so the two documents cannot drift. *(completed)*
  - [x] Confirm no task-number references leak into either deliverable file (both live outside
        `specs/**`). *(completed: grep found none)*
- **Timing:** 0.5 hours
- **Depends on:** 2
- **Verification Tier:** prose
- **Commit Mode:** per-substep
- **Scope Hypothesis:** This phase asserts three edited prose regions — the schema doc's
  Deferral-Direction `in_batch` bullet, its Determinism section, and its Version History — plus
  the mirrored header comment in the script. Confirm at implementation time by grepping both files
  for `in_batch` and for the stale phrase "defers instead": every surviving occurrence must either
  be updated or be demonstrably about a different rule. An occurrence found in a third file means
  the prose has a consumer this hypothesis missed, and that file must be added to this phase.
- **Files to modify**:
  - `agent-system/extensions/core/docs/architecture/batch-admit-schema.md` - narrow the `in_batch`
    deferral-direction bullet, update Determinism, add a no-bump Version History entry
  - `agent-system/extensions/core/scripts/orchestrate-batch-admit.sh` - mirror the narrowed rule in
    the header comment block (comment-only hunks)
- **Verification**:
  - Diff read-through confirming every changed hunk in the script lies inside a comment block (no
    executable line touched in this phase).
  - `grep -n 'defers instead' agent-system/extensions/core/docs/architecture/batch-admit-schema.md
    agent-system/extensions/core/scripts/orchestrate-batch-admit.sh` returns no stale, unqualified
    occurrence.
  - The Version History entry explicitly states no `$schema` bump and names the precedent entry it
    is modeled on.

---

### Phase 4: Full gate run and consumer non-regression check [IN PROGRESS]

- **Goal:** Run the complete repository test net and confirm no verdict consumer regressed.
- **Tasks:**
  - [ ] Run `bash agent-system/extensions/core/scripts/tests/run-all.sh` and confirm the new suite
        is discovered (it must appear as `[RUN]`/`[PASS]`, never `[SKIP]` — a `[SKIP]` means the
        exec bit was lost).
  - [ ] Confirm zero `[FAIL]` lines in the run-all output (`grep '^\[FAIL\] '` returns nothing) and
        the harness exit code is 0.
  - [ ] Read-only confirmation that the three verdict consumers need no change: grep
        `orchestrate-cycle-plan.sh`, `orchestrate-dry-run-report.sh`, and
        `orchestrate-predispatch-review.sh` for `defer_reason`, `collision_scope`, and
        `colliding_task_number` and confirm each branches on the verdict fields only, never on why
        a lower-numbered peer was or was not admitted.
  - [ ] Record in the implementation summary that `.claude/scripts/orchestrate-batch-admit.sh` is a
        regenerated deploy artifact: the fix takes effect for live `/orchestrate` runs only after
        the next deploy/reload, not from the source-store edit alone.
- **Timing:** 0.5 hours
- **Depends on:** 2, 3
- **Verification Tier:** full
- **Commit Mode:** per-substep
- **Scope Hypothesis:** This phase asserts zero file modifications — it is verification only. A
  non-empty `git status --short` for tracked files at this phase's close (beyond specs/ artifacts)
  means a gate failure prompted an unplanned fix; that fix belongs to Phase 2 or 3 and must be
  attributed there, not silently absorbed here.
- **Files to modify**:
  - None (verification phase)
- **Verification**:
  - `run-all.sh` exits 0 with the new suite discovered and passing.
  - `test-conflict-predicate.sh` and `test-orchestrate-batch-admit.sh` both exit 0 individually.
  - Consumer grep confirms no `decision`/`defer_reason`/`collision_scope` branch depends on the
    changed internal criterion.

---

## Testing & Validation

- [ ] `test-orchestrate-batch-admit.sh` Case 1 fails on the unmodified script (red baseline
      recorded in Phase 1) and passes after Phase 2.
- [ ] `test-orchestrate-batch-admit.sh` Case 2 asserts NDJSON row order matches caller-argument
      order for non-ascending arguments (`D C A B`).
- [ ] `test-orchestrate-batch-admit.sh` Case 3 (if encoded) confirms the narrowing is uniform
      across defer reasons: a self-modification-caused defer also keeps a lower-numbered peer out
      of the admitted set.
- [ ] `test-conflict-predicate.sh` exits 0 — `session_active` / `corroborated_by` /
      `idle_overlap_advisory` behavior unchanged.
- [ ] `run-all.sh` exits 0 with no `[FAIL]` and no `[SKIP]` for the new suite.
- [ ] `bash -n` clean on the modified script.
- [ ] Verdict schema unchanged: `$schema` still `orchestrate-batch-admit-v5`, no field added,
      removed, or repurposed.

## Artifacts & Outputs

- `agent-system/extensions/core/scripts/tests/test-orchestrate-batch-admit.sh` (new regression
  suite)
- `agent-system/extensions/core/scripts/orchestrate-batch-admit.sh` (modified: reduce-based greedy
  admitted-set walk, narrowed `in_batch` predicate, updated header prose)
- `agent-system/extensions/core/docs/architecture/batch-admit-schema.md` (modified: narrowed
  deferral-direction rule, updated Determinism, new no-bump Version History entry)
- `specs/245_batch_admit_defer_against_admitted_set_only/summaries/01_*-summary.md` (implementation
  summary)

## Rollback/Contingency

The change is confined to three files in the source store, committed per green sub-step, so the
ordinary contingency is `git revert` of the specific phase commits — no working-tree discard is
involved and no snapshot is required.

If the reduce restructuring proves unexpectedly invasive (for example, a jq construct in a moved
branch body that does not survive the fold), fall back to the narrower shape: keep the existing
top-level generator, but precompute the admitted set in a *separate* preceding `reduce` that
evaluates only the collision-relevant predicate per candidate in ascending order, and have the
unchanged generator consult that precomputed set. This duplicates part of the predicate — an
acceptable, documented cost — but leaves every branch body physically untouched. Choose this
fallback only if Phase 2's verbatim-move approach fails verification twice; record the choice and
its rationale in the implementation summary.

If a working-tree rollback ever does become necessary (it should not for this task), follow
`context/contracts/recovery.md`'s rollback rung for the correct snapshot-then-rollback invocation
shape, including its out-of-scope override flag — never a bare precautionary `git-snapshot.sh`
call.

Note: `.claude/scripts/orchestrate-batch-admit.sh` is a regenerated deploy artifact and must never
be hand-edited. Reverting the source store and re-deploying is the complete rollback; no `.claude/`
cleanup is required.
