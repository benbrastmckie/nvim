# Implementation Plan: Task #181

- **Task**: 181 - Unify the /orchestrate inter-cycle redeploy checkpoint gate depth and verdict trustworthiness
- **Status**: [IMPLEMENTING]
- **Effort**: 6 hours
- **Dependencies**: consumer-scan opt-in task (shared `deploy-headless.sh` footprint; removes latency this plan's confirmation re-run would otherwise compound)
- **Research Inputs**: None (no research report; the task description carried verified mechanics and in-session evidence, and the four target files were read directly during planning)
- **Artifacts**: plans/01_unify-redeploy-checkpoint-gate.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Three defects in the inter-cycle redeploy checkpoint combine to produce a contradictory,
unactionable, whole-batch deferral. This plan fixes all three under one coherent verdict
pipeline: the baseline comparison keeps its full-depth intent (explicitly, not silently), a
would-be-deferring finding set is first passed through a **confirmation filter** (re-run once;
a finding that does not reproduce is flaky) and then an **attribution filter** (a confirmed
finding that positively names an identifier absent from the batch's own `modified_files` is
unrelated), and only findings surviving both filters defer — naming themselves in the message
and in the `defer_ledger` detail.

The design deliberately extends the existing branch (c) philosophy ("a pre-existing, unrelated
red gate must not defer the whole batch") from *temporally* pre-existing to *causally*
unattributable, rather than lowering the gate depth or disabling any gate.

### Research Integration

No research report exists for this round. The Stage 1.5 opening assessment found the task
description to be a specification rather than a research question: it carried the observed
session evidence, the verified three-pass mechanics, the explicit preserve-list, and the
acceptance criterion. Planning confirmed every load-bearing claim by direct read:

- **`--skip-slow` defers gate 8 and nothing else** (`verify-deploy.sh` lines 46-49, 478-500).
  The fast set is therefore exactly the full set minus gate-8 findings, so the Defect A depth
  mismatch is entirely and only about the shell test suite runner.
- **The checkpoint's own pre/post snapshots are already symmetric** (both full depth,
  `orchestrate-cycle-plan.sh` lines 585 and 607). The observed deferral was therefore not caused
  by pre/post asymmetry but by a genuine gate-8 delta — the flake. Symmetry must be *preserved*:
  an asymmetric pre/post would make every gate-8 finding look new, a strictly worse bug.
- **`deploy_exit` already distinguishes the fast verdict**: exit 0 = `landed_verify_clean` (fast
  PASS), exit 3 = `landed_verify_red`. The checkpoint can therefore detect a fast-PASS/full-FAIL
  disagreement with no new plumbing.
- **Gate-8 findings name the failing suite** (`FINDING gate8 <run-all [FAIL] line>`), which is
  what makes the attribution filter tractable for the observed `test-lake-build-guard.sh` case.
- **`new_findings` is already in scope and non-empty on exactly the defer branch** (line 616),
  confirming Defect B is a pure message fix.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No `specs/ROADMAP.md` exists in this repository; no roadmap consultation was possible and no
roadmap phases are included.

## Goals & Non-Goals

**Goals**:
- A checkpoint verdict that is *trustworthy* (no deferral on a flaky or unrelated finding) and
  *actionable* (the message and ledger name the specific finding).
- A single, explicitly-documented gate depth story, with any fast/full disagreement reported as
  such rather than silently resolved in favor of deferral.
- The new filtering algorithm lives in `lib/deploy-baseline-lib.sh`, the file whose stated
  purpose is to be the single home of this comparison, so the two consumers cannot re-diverge.
- Test coverage proving: flaky does not defer, unrelated does not defer, genuine attributable
  still defers, and the message names the finding.

**Non-Goals**:
- Lowering the checkpoint's gate depth or removing gate 8 from the blocking set. Gate 8 is the
  shell test suite — the single richest source of real signal about broken orchestrator scripts.
  Making it non-blocking would be the "simply disable the gate" outcome the task forbids.
- Adding a per-gate selector flag to `verify-deploy.sh` to make the confirmation re-run cheaper.
  Tempting, but it widens a heavily-consumed interface for a rare code path.
- Changing branch (a) (deploy exit 1/2, unconditional defer, exit 3 excluded) or branch (c)
  (unchanged/shrunk finding set proceeds loudly). Both are on the PRESERVE list.
- Widening Stage MT-3 step 7's trigger predicate (the 2026-09-08 scope note). See Phase 5 — this
  is split out explicitly, not dropped.

## Design Decisions

Recorded here so a later reader does not re-litigate them; the task text asked that the approach
be chosen at planning time from the enumerated options.

**Defect A — chosen: keep two depths, make the mismatch explicit.** Of the three offered
approaches, "verify once at a single depth" would require either lowering the checkpoint to
`--skip-slow` (dropping gate 8 from the blocking baseline — a real weakening) or raising
`deploy-headless.sh`'s internal verify to full depth (imposing ~2.8min on every deploy for every
other caller). "Consume deploy-headless.sh's own result" has the same depth-lowering
consequence. The third option — report the disagreement — preserves the documented full-depth
intent verbatim (no silent reversal to be re-reverted) while removing the contradiction from the
operator's view. The existing comment above `post_findings` is *extended*, not deleted.

**Defect C — chosen: confirmation filter first, attribution filter second.** Confirmation
directly kills the observed failure mode (checkpoint-self-inflicted load making a load-sensitive
test flake) without weakening the gate at all: a real breakage reproduces. Attribution then
satisfies the acceptance criterion's "or unrelated to the batch's own modified_files" clause.
The attribution filter is deliberately **fail-safe toward deferring**: a finding is treated as
attributable unless it *positively* names a concrete identifier (a path or a basename) that
appears nowhere in the batch's `modified_files`. A finding naming no identifier at all cannot be
shown unrelated, so it defers. This is what keeps the filter from becoming a blanket disable.

**Scope of the new lib functions.** They are additive and wired only into the checkpoint.
`command-gate-out.sh`'s `rc==6` handler deliberately keeps the unfiltered comparison: it gates a
single task's own completion, where attribution to that one task is the entire point and the
operator is present to judge a flake. The checkpoint gates an entire batch with no operator
present. This asymmetry is intentional and must be commented at both call sites.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Attribution filter too permissive, silently swallowing a real regression | H | M | Fail-safe direction: only *positively* unrelated findings are dropped; identifier-free findings still defer. Every dropped finding is recorded verbatim in a notice, never discarded silently. |
| Confirmation re-run adds ~2.8min to the defer path | L | H | Fires only on the would-be-defer branch (rare). Cheap next to deferring a whole batch. Dependency task removes compounding latency. |
| Pre/post depth accidentally made asymmetric while "fixing" depth | H | L | Phase 3 explicitly asserts symmetry; Phase 4 adds a regression test that a gate-8 finding present in BOTH pre and post is not treated as new. |
| Silent reversal of the documented full-depth choice | M | M | The comment is extended with the superseding argument in the same edit (Phase 3), and the doc subsection is updated (Phase 5). |
| Branch (a)/(c) behavior regressed while restructuring the (b) branch | H | L | Existing Group 11 cases (a)/(b)/(c) are left untouched and must still pass (Phase 4 gate). |
| Edits land in `.claude/**` instead of the source store | H | M | Every phase names `agent-system/extensions/core/**` paths explicitly; see `rules/source-store-deploy-boundary.md`. |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1, 2 | -- |
| 2 | 3 | 1, 2 |
| 3 | 4, 5 | 3 |

Phases within the same wave can execute in parallel. Wave 1's two phases touch disjoint files
(`orchestrate-cycle-plan.sh` vs. `lib/deploy-baseline-lib.sh`); wave 3's two phases likewise
(the test suite vs. the guardrails doc).

---

### Phase 1: Name the failing finding in the defer message and ledger (Defect B) [COMPLETED]

**Goal**: The operator can act on a checkpoint deferral without re-running the whole gate.

**Tasks**:
- [x] In `orchestrate-cycle-plan.sh`'s branch (b) (currently line ~627), emit the contents of
      `new_findings` after the warning line, one finding per line, indented for readability. *(completed)*
- [x] Replace the `defer_ledger` entry's generic `detail` string (currently line ~630,
      `"verify-deploy.sh new findings vs. pre-redeploy baseline"`) with one carrying the finding
      identity — pass `new_findings` through `jq --arg` and store both a count and the finding
      lines. Keep the `defer_reason` field value `"deploy_checkpoint"` unchanged (it is matched
      elsewhere). *(completed)*
- [x] Confirm the emitted findings go to stderr, consistent with every other checkpoint message. *(completed)*

**Timing**: 0.5 hours

**Depends on**: none

**Verification Tier**: local

**Files to modify**:
- `agent-system/extensions/core/scripts/orchestrate-cycle-plan.sh` - branch (b) message + ledger detail

**Verification**:
- `bash -n` on the modified script passes.
- Existing Group 11 case (b) in `test-orchestrate-cycle-plan.sh` still passes.
- A manual `jq` read of the case (b) fixture's `defer_ledger[0].detail` shows the stub's
  `FINDING gate2 NEW` text rather than the generic string.

---

### Phase 2: Add the confirmation and attribution filters to the shared baseline library [COMPLETED]

**Goal**: The two new set operations exist, are documented, and are correct in isolation.

**Tasks**:
- [x] Add `deploy_baseline_confirm_new_findings <candidate_new> <confirm_snapshot>` to
      `lib/deploy-baseline-lib.sh`: prints the intersection (`comm -12`) of the candidate new
      findings and a freshly-taken confirmation snapshot. Findings absent from the confirmation
      run are the flaky ones and are excluded. *(completed)*
- [x] Add `deploy_baseline_unattributable_findings <findings> <modified_files_json>`: prints
      those findings that positively name an identifier (a `/`-bearing path token or a
      `.sh`/`.md`/`.lua`/`.json` basename) where NO such identifier matches any entry in
      `modified_files` (basename match, so a full path in the finding matches a repo-relative
      path in `modified_files`). A finding bearing no identifier at all is NOT printed — it is
      not shown unrelated, so it stays blocking. *(completed)*
- [x] Extend the library's header comment block: state that these two functions are additive,
      checkpoint-only, and why `command-gate-out.sh`'s `rc==6` handler deliberately does not use
      them (single-task gate, operator present). *(completed)*
- [x] Preserve the file's existing invariants: never abort, never propagate an invoked script's
      exit code, `sort -u` inputs, safe to source under a caller's `set -e -o pipefail`. The
      `|| true` discipline around `grep`/`comm` in the existing functions is the pattern to
      follow — a no-match `grep` must not abort the sourcing caller. *(completed)*

**Timing**: 1.5 hours

**Depends on**: none

**Verification Tier**: local

**Scope Hypothesis**: This phase assumes exactly two new functions suffice and that no change to
`deploy_findings_snapshot` is required (the confirmation re-run reuses it verbatim with the same
full-depth arguments). The implementer must confirm while writing Phase 3's wiring that no third
helper is needed; if the wiring turns out to need a fourth set operation, add it here rather
than inlining it at the call site.

**Files to modify**:
- `agent-system/extensions/core/scripts/lib/deploy-baseline-lib.sh` - two new functions + header

**Verification**:
- A throwaway driver script sourcing the library exercises both functions against hand-built
  fixtures: an all-flaky candidate set yields empty confirmed output; a fully-reproduced set
  yields itself; a finding naming `test-lake-build-guard.sh` with that file absent from
  `modified_files` is reported unattributable; the same finding with that file present is not;
  an identifier-free finding is never reported unattributable.
- Sourcing the library under `set -e -o pipefail` and calling each function with empty inputs
  does not abort the caller.

---

### Phase 3: Wire the unified verdict pipeline into the checkpoint (Defects A + C) [COMPLETED]

**Goal**: The checkpoint defers only on confirmed, attributable findings, and reports a
fast/full depth disagreement as such.

**Tasks**:
- [x] In the `else` (deploy landed) branch, after `new_findings` is computed and found
      non-empty, take ONE confirmation snapshot via `deploy_findings_snapshot` at the SAME full
      depth as the pre/post pair, and derive `confirmed_new` and the dropped `flaky` set. *(completed)*
- [x] Apply `deploy_baseline_unattributable_findings` to `confirmed_new` using the
      `cycle_modified_files_json` already read at the top of the checkpoint block, deriving
      `unrelated` and the final `blocking` set. *(completed)*
- [x] If `blocking` is empty: take the branch (c)-equivalent path — proceed loudly, record
      `deployed_critical_paths`, and record a `verify_deploy_baseline_notices` entry carrying the
      flaky and unrelated finding lines and their counts, plus a distinguishing marker so this
      new sub-branch is not confused with the original (c). Emit a clear stderr line stating the
      batch is continuing and why. *(completed)*
- [x] If `blocking` is non-empty: defer, reusing Phase 1's finding-naming message and ledger
      detail but now printing the `blocking` set (not the raw `new_findings`). *(completed)*
- [x] Defect A reporting: when `deploy_exit -eq 0` (deploy-headless reported
      `landed_verify_clean` at `--skip-slow` depth) and `blocking` is non-empty, add an explicit
      line stating that the deploy's own fast verify passed and that these findings come from
      the slow gate deferred by `--skip-slow`, so the two verdicts are a depth disagreement, not
      a contradiction. Record the depth in the notice/ledger entry. *(completed)*
- [x] Extend — do not delete — the comment block above `post_findings`. Keep the original
      full-depth argument, then state that the depth asymmetry against `deploy-headless.sh`'s
      internal `--skip-slow` run is now explicitly reported rather than silently resolved. *(completed)*
- [x] Assert (in a comment) that the pre and post snapshots must remain at identical depth, and
      why an asymmetric pair would make every gate-8 finding look new. *(completed)*
- [x] Leave branch (a) and the original branch (c) untouched. *(completed)*

**Timing**: 1.5 hours

**Depends on**: 1, 2

**Verification Tier**: interface

**Scope Hypothesis**: This phase assumes the checkpoint needs no new top-level `mt_state` key —
the new detail rides inside the existing `verify_deploy_baseline_notices` and `defer_ledger`
arrays, both already defaulted at lines ~412-413. The implementer must confirm this while
wiring; if a new top-level key does prove necessary, it needs a matching `//= []` default beside
the others, or downstream readers will see `null`.

**Files to modify**:
- `agent-system/extensions/core/scripts/orchestrate-cycle-plan.sh` - the (b)/(c) branch pipeline, depth reporting, comments

**Verification**:
- `bash -n` passes.
- All existing Group 11 cases (a), (b), (c) still pass unchanged.
- A dry-run trace confirms the confirmation snapshot is taken ONLY when `new_findings` is
  non-empty — a clean or branch-(c) run must still make exactly two `verify-deploy.sh` calls.

---

### Phase 4: Test coverage for the new verdict behavior [NOT STARTED]

**Goal**: The new contract is pinned by tests, including the regressions this plan's own design
could introduce.

**Tasks**:
- [ ] Extend the Group 11 stub helpers so `write_g11_verify_stub` can serve a THIRD response
      (the confirmation snapshot), driven by the existing call-counting marker.
- [ ] Case (d) — **flaky does not defer**: post reports a new finding, the confirmation snapshot
      does not reproduce it. Assert the batch is NOT deferred, a notice records the finding as
      flaky, and `deployed_critical_paths` was still recorded.
- [ ] Case (e) — **unrelated does not defer**: a confirmed new finding names a file absent from
      `cycle_modified_files`. Assert no deferral and a notice recording it as unrelated.
- [ ] Case (f) — **genuine attributable still defers**: a confirmed new finding names a file
      present in `cycle_modified_files`. Assert `deferred_deploy_checkpoint` contains the task.
- [ ] Case (g) — **the defer message names the finding**: assert the captured stderr contains
      the specific finding text, and that `defer_ledger[].detail` does too.
- [ ] Case (h) — **identifier-free finding still defers**: a confirmed new finding naming no
      path or basename must NOT be filtered out as unrelated.
- [ ] Case (i) — **depth symmetry regression guard**: a gate-8 finding present in BOTH pre and
      post snapshots is not treated as new and takes the original branch (c).
- [ ] Case (j) — **call-count guard**: a branch (c) run takes exactly two `verify-deploy.sh`
      calls (no confirmation pass when there is nothing to confirm).

**Timing**: 1.5 hours

**Depends on**: 3

**Verification Tier**: full

**Scope Hypothesis**: Seven new cases (d) through (j) are the anticipated set, and the existing
`$SCRIPT_DIR`-interposition stub convention documented in the Group 11 header is assumed to
extend to a third stub response without new machinery. Both are hypotheses: confirm by running
the suite, and add or drop cases as the wiring actually requires rather than forcing the count.

**Files to modify**:
- `agent-system/extensions/core/scripts/tests/test-orchestrate-cycle-plan.sh` - Group 11 extensions

**Verification**:
- `bash agent-system/extensions/core/scripts/tests/test-orchestrate-cycle-plan.sh` passes with
  zero failures, existing cases included.
- `bash agent-system/extensions/core/scripts/tests/run-all.sh --quiet` reports no new failures
  (run on an idle machine — this suite is the one whose load sensitivity motivated the task).

---

### Phase 5: Update the authoritative contract doc and split out the trigger-predicate widening [NOT STARTED]

**Goal**: The single authoritative statement of the checkpoint contract matches the code, and
the 2026-09-08 scope note is resolved by an explicit, recorded split rather than silence.

**Tasks**:
- [ ] Update `### The Inter-Cycle Redeploy Checkpoint`'s **Failure contract** to document the
      confirmation and attribution filters as the path from a raw new-finding set to the
      blocking set, presented as an extension of branch (c)'s existing "unrelated red gate must
      not defer the batch" philosophy from temporally pre-existing to causally unattributable.
- [ ] Add an explicit **Gate depth** statement: the checkpoint's pre/post pair runs at full
      depth and MUST stay symmetric; `deploy-headless.sh`'s internal run is `--skip-slow` (gate 8
      only); a fast-PASS/full-FAIL disagreement is reported as a depth disagreement.
- [ ] State that the defer message and `defer_ledger` detail name the specific blocking
      findings.
- [ ] Record the fail-safe direction of the attribution filter (identifier-free findings still
      defer) so a later pass does not "simplify" it into a blanket filter.
- [ ] Sharpen the existing follow-up note (currently ~line 636) on widening Stage MT-3 step 7's
      predicate: state that it was explicitly considered during this task and **split out**
      because this task changed the checkpoint's *verdict* logic while that change targets its
      *trigger* predicate and the `deployed_critical_paths` idempotence backing store — disjoint
      mechanisms with no shared edit. Keep it named as owed follow-up work.
- [ ] Surface the split-out item in the implementation summary so the operator can create the
      follow-up task; do not create it silently as a side effect of this task.
- [ ] Check the cross-referencing files named in the subsection header
      (`regeneration-is-manual-only.md`, `skill-orchestrate/SKILL.md`,
      `docs/architecture/orchestrate-state-machine.md`, `deploy-headless.sh`,
      `verify-deploy.sh`) still only cross-reference by path and need no edit; correct any that
      restate the now-changed contract.

**Timing**: 1 hour

**Depends on**: 3

**Verification Tier**: prose

**Files to modify**:
- `agent-system/extensions/core/context/patterns/batch-orchestration-guardrails.md` - checkpoint subsection + follow-up note

**Verification**:
- The documented branches match the implemented ones, read side by side.
- `verify-deploy.sh`'s doc-lint gate (gate 3) reports no new findings for the edited file.
- A grep for the checkpoint's name across the cross-referencing files shows no file restating a
  superseded contract.

---

## Testing & Validation

- [ ] Flaky new finding does not defer the batch (acceptance criterion, Defect C).
- [ ] Unrelated new finding does not defer the batch (acceptance criterion, Defect C).
- [ ] A genuine, confirmed, attributable new finding still defers (gate not disabled).
- [ ] The defer message and `defer_ledger` detail name the specific finding (Defect B).
- [ ] A fast-PASS/full-FAIL disagreement is reported as a depth disagreement (Defect A).
- [ ] Branch (a) — deploy exit 1/2 defers unconditionally with no baseline consultation, exit 3
      still excluded (PRESERVE).
- [ ] Branch (c) — unchanged/shrunk finding set proceeds loudly with a notice (PRESERVE).
- [ ] Full `run-all.sh` shell test suite green on an idle machine.
- [ ] No file under `.claude/**` was hand-edited.

## Artifacts & Outputs

- Modified: `agent-system/extensions/core/scripts/orchestrate-cycle-plan.sh`
- Modified: `agent-system/extensions/core/scripts/lib/deploy-baseline-lib.sh`
- Modified: `agent-system/extensions/core/scripts/tests/test-orchestrate-cycle-plan.sh`
- Modified: `agent-system/extensions/core/context/patterns/batch-orchestration-guardrails.md`
- Implementation summary naming the split-out follow-up (trigger-predicate widening)

## Rollback/Contingency

Every change is additive and confined to four source-store files with no schema migration. If
the filters prove too permissive in live use, the contingency is to disable the attribution
filter alone (leaving the confirmation filter, which cannot weaken the gate — a real breakage
reproduces) by making `blocking` equal `confirmed_new`; that is a one-line revert at the Phase 3
call site and does not require unwinding the library or the tests. Full rollback is
`git revert` of the phase commits, after which the checkpoint returns to its current
three-branch behavior. No deploy state is mutated beyond `deployed_critical_paths`, which is
already idempotent under `unique`.
