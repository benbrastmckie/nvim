# Implementation Plan: Task #200

- **Task**: 200 - Close the consumer-repo deploy propagation gap that leaves fixed defects live in deployed trees
- **Status**: [NOT STARTED]
- **Effort**: 8 hours
- **Dependencies**: None
- **Research Inputs**: specs/200_consumer_deploy_propagation_gap/reports/01_consumer-deploy-propagation-gap.md
- **Artifacts**: plans/01_per-dispatch-freshness-surface.md (this file)
- **Standards**:
  - .claude/context/formats/plan-format.md
  - .claude/context/standards/status-markers.md
  - .claude/rules/artifact-formats.md
  - .claude/rules/state-management.md
  - .claude/rules/source-store-deploy-boundary.md
  - .claude/rules/no-task-references-in-deliverables.md
  - .claude/context/standards/shell-strict-mode.md
- **Type**: meta
- **Lean Intent**: false

## Overview

A defect fixed in the source store can stay live in a consuming repo's deployed `.claude/` tree
indefinitely, misleading every agent that reads it. Research established that the gap is **not a
missing detector** — a pull-side, per-extension, path-scoped freshness detector
(`check-deploy-freshness.sh` + `scripts/lib/deploy-freshness-lib.sh`) already exists and already
fires non-blockingly from `command-gate-in.sh`'s CHECKPOINT 1. The gap is **granularity and
placement**: that check runs once per top-level command, and its WARN lands on the orchestrating
session's own stderr, never in the context of the spawned agent that actually reads the stale
file. This plan closes that gap by (a) calling the existing comparison library from
`skill_preflight_update` in `core/scripts/skill-base.sh`, which runs once per skill/agent
dispatch, and (b) injecting a `<deploy-freshness-context>` block into the dispatch file that the
spawned agent itself reads, using the same injection mechanism
`orchestrate-build-dispatch.sh` already uses for `<memory-context>`. No new comparison
algorithm, no new fingerprint scheme, and nothing added to any blocking gate path. Done when a
partial-staleness fixture (one file identical, one file stale, same tree) is detected by a pinned
regression test, the per-dispatch wall-clock cost is measured and shown to be in the ~130ms class
rather than the ~10-minute fleet-walk class, and the recommendation plus its rejected
alternatives are recorded in the source store's own pattern documentation.

### Research Integration

Findings from `reports/01_consumer-deploy-propagation-gap.md` that this plan builds on directly:

- **The dispatch's "the only detector is opt-in and report-only" framing is accurate for tier 3
  only** (`check-consumer-freshness.sh`, behind `--consumer-report`). Tier 1
  (`check-deploy-freshness.sh`) is neither opt-in nor inert-by-design; it is inert *by
  granularity*. The plan corrects this framing rather than building on the premise that no
  pull-side check exists.
- **Recommendation adopted**: option (a) pull-side check, at a finer location than the dispatch
  suggested — `skill_preflight_update` in `core/scripts/skill-base.sh`, confirmed to run once per
  skill/agent dispatch (`orchestrate-cycle-plan.sh`'s per-task live-dispatch loop calls it), not
  once per top-level command — combined with a scoped slice of option (c): surface the result
  into the dispatch brief the agent reads, warn-loudly, never hard-block.
- **Option (b) rejected as a new mechanism**: the existing per-extension path-scoped
  `source_git_head` comparison (`git log -1 --format=%H -- <source_dir>`) already operates at
  extension-directory granularity, so a single changed file inside an otherwise-untouched
  extension already moves the recomputed revision. Building a second whole-tree fingerprint
  would duplicate work the library already does. Phase 2 pins this claim with a fixture instead
  of asserting it.
- **Measured baseline**: ~0.133s for the full 7-extension check in a real consumer repo. Cost
  scales with the *checking repo's own* extension count, never with the consumer-fleet size —
  categorically different from the ~50-repo walk that was correctly removed from the blocking
  path.
- **The four cited lean call sites in `~/Projects/BimodalLogic` already match source as of
  2026-09-17** (a redeploy happened there independently). The acceptance step re-confirms this
  after the change lands; it is a verification, not a drift-fixing migration.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No `roadmap_path` provided in the dispatch context; no ROADMAP.md consulted.

## Goals & Non-Goals

**Goals**:
- Detect a consuming repo's divergence from the source store at **per-dispatch** granularity, at
  the moment the information can still change what the dispatched agent does.
- Make the already-detected signal **reach the spawned agent's own context**, not only the
  orchestrating session's stderr.
- Prove **partial** staleness detection with a fixture reproducing the observed shape: one file
  byte-identical, one file stale, within the same tree.
- Measure the per-dispatch wall-clock cost and show it does not reintroduce the blocking-gate
  regression that was previously removed.
- Record the recommendation and the rejected alternatives durably in the source store's pattern
  documentation.
- Keep every touched script `shellcheck` clean per `context/standards/shell-strict-mode.md`.

**Non-Goals**:
- Re-fixing the lean extension's source documentation — it is already correct at source and MUST
  be left alone.
- Restoring the fleet-wide consumer walk onto any blocking gate path. The opt-in
  `--consumer-report` design stays exactly as it is.
- Building a new whole-tree content-hash or manifest-digest fingerprint (option b as a standalone
  mechanism).
- Hard-blocking or refusing a dispatch on a `STALE` result. This is recorded as a deliberately
  rejected-for-now alternative, not implemented.
- Redeploying every registered consumer repo as a data-migration exercise.
- Inventing a second consecutive-ignore streak mechanism; the existing
  `specs/.freshness-warn-streak.json` escalation stays the only one.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| A new call inside `skill_preflight_update` aborts under a caller's `set -e`, killing every lifecycle dispatch | H | M | The new surface is a sourced-library call wrapped so every failure mode (missing library, missing jq/git, unparseable state file) degrades to a silent no-op, mirroring `check-deploy-freshness.sh`'s always-exit-0 contract. Phase 3 carries a `full` verification tier for exactly this reason; Phase 5 pins the no-abort behavior with a missing-library case. |
| Per-dispatch invocation multiplies the ~130ms cost across a session | M | H | Phase 6 measures a realistic multi-dispatch session end to end and compares against the recorded Phase 1 single-invocation baseline. Cost scales with this repo's own extension count (7), not the 8-repo consumer fleet. If the measured multi-dispatch total exceeds the recorded ceiling, the phase records the overrun rather than silently accepting it. |
| Conflating `CANNOTVERIFY` with `STALE` would make missing `jq`/`git`/a non-git `source_dir` read as an alarm | M | M | The library already keeps the three values distinct. The new surface consumes `deploy_freshness_stale_names` (which emits only conclusive staleness), never a collapsed boolean. Phase 5 pins a `CANNOTVERIFY` case asserting silence. |
| The source-store edits in Phases 3-4 make this repo's own `core` extension read STALE until redeployed, producing self-warnings mid-implementation | L | H | Expected and correct — it is the mechanism demonstrating itself. The implementer should note it rather than suppress it, and Phase 7's redeploy clears it. Do NOT hand-patch `.claude/**` to silence it. |
| Dispatch-brief injection only covers orchestrator-mode dispatches; a directly-invoked skill run would not get the block | M | H | Accepted and documented: the `skill_preflight_update` surface (Phase 3) is the base layer covering both paths; the dispatch-brief injection (Phase 4) is an orchestrate-mode enhancement on top, never a replacement. Phase 7's documentation states this split explicitly. |
| A new warning becomes another ignored non-blocking line, exactly like the one that already failed | H | M | The change is specifically about *placement*, not volume: the block lands in the dispatched agent's own read-first context, where it is actionable at the moment of use. The existing streak escalation remains available as a future louder default and is documented as such in Phase 7. |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1, 2 | -- |
| 2 | 3 | 1, 2 |
| 3 | 4 | 3 |
| 4 | 5, 6 | 3, 4 |
| 5 | 7 | 5, 6 |

Phases within the same wave can execute in parallel.

---

### Phase 1: Confirm premises and record the cost baseline [NOT STARTED]

**Goal**: Establish, by measurement rather than assertion, the two numbers the acceptance
criterion depends on, and confirm the source store needs no lean-doc fix.

**Tasks**:
- [ ] Confirm the lean extension's four cited call sites are already correct at source: diff
      `agent-system/extensions/lean/agents/lean-implementation-agent.md`,
      `.../lean-implementation-hard-agent.md`, `.../rules/lean4.md`, and
      `.../skills/skill-lake-repair/SKILL.md` against `~/Projects/BimodalLogic/.claude/`'s
      corresponding deployed files. Record the result. Make NO edit to any lean source file
      regardless of the outcome.
- [ ] Measure single-invocation cost: run `time bash .claude/scripts/check-deploy-freshness.sh .`
      in this repo and in `~/Projects/BimodalLogic`, at least 5 runs each, and record min/median.
- [ ] Count the extensions actually deployed in each repo (`jq '.extensions | keys | length'` on
      each `.claude-extensions.json`) so the per-extension cost is derivable, not just the total.
- [ ] Record the registered-consumer count from
      `agent-system/extensions/core/context/reference/known-consumer-repos.json` for the
      cost-contrast argument.
- [ ] Write all measurements to `specs/200_consumer_deploy_propagation_gap/measurements.md` with
      the exact commands used, so Phase 6 can compare against a recorded baseline rather than a
      remembered one.

**Timing**: 0.75 hours

**Depends on**: none

**Verification Tier**: prose

**Commit Mode**: per-substep

**Scope Hypothesis**: Research asserts ~0.133s for 7 extensions in `~/Projects/BimodalLogic`, and
that all four lean call sites already match source. Both are hypotheses. Confirm by re-running
the timing and the diffs at implementation time; if either differs, record the measured value and
carry it forward instead of the research figure.

**Files to modify**:
- `specs/200_consumer_deploy_propagation_gap/measurements.md` - new; measurement record (inside
  `specs/**`, so task-number references are permitted here)

**Verification**:
- `measurements.md` exists, is non-empty, and names every command used.
- No file under `agent-system/extensions/lean/**` is modified (`git status` confirms).
- No file under any repo's `.claude/**` is modified by hand.

---

### Phase 2: Pin partial staleness with a fixture [NOT STARTED]

**Goal**: Prove — with a regression test, not an argument — that the existing per-extension
path-scoped comparison already catches a single stale file inside an otherwise-untouched tree,
which is the claim option (b) would otherwise be built to satisfy.

**Tasks**:
- [ ] Read `agent-system/extensions/core/scripts/tests/test-deploy-freshness.sh` in full and
      extend it in its existing idiom (`pass`/`fail`/`info` helpers, PASSED/FAILED counters,
      trap-based scratch `WORKDIR`, exit 0/1/2 contract, Class B `set -uo pipefail`).
- [ ] Add a fixture case reproducing the observed shape: a scratch source repo with an extension
      directory containing TWO committed files; a consumer `.claude-extensions.json` recording
      `source_git_head` at that commit; then commit a change to exactly ONE of the two files,
      leaving the other byte-identical.
- [ ] Assert `deploy_freshness_status <consumer> <ext>` returns `STALE` for that extension while
      the untouched file's byte-identity is independently confirmed in the fixture (so the test
      documents *why* this is the partial-staleness case, not just that a hash moved).
- [ ] Add a second extension to the same consumer fixture whose source directory received no
      commit, and assert it returns `FRESH` in the same run — reproducing "one fresh, one stale
      in the same tree" and proving a spot-check of the fresh one would have concluded wrongly.
- [ ] Assert `deploy_freshness_stale_names <consumer>` lists the stale extension and omits the
      fresh one.
- [ ] Run the suite; confirm all existing cases still pass alongside the new ones.

**Timing**: 1.0 hours

**Depends on**: none

**Verification Tier**: local

**Commit Mode**: per-substep

**Scope Hypothesis**: This phase assumes the extension is exercisable without modifying
`deploy-freshness-lib.sh` itself. Confirm at implementation time by running the new cases against
the unmodified library; if a library change turns out to be required, stop and record that
finding rather than silently widening the phase — it would invalidate the "no new mechanism
needed" recommendation.

**Files to modify**:
- `agent-system/extensions/core/scripts/tests/test-deploy-freshness.sh` - add the
  partial-staleness fixture cases described above

**Verification**:
- `bash agent-system/extensions/core/scripts/tests/test-deploy-freshness.sh` exits 0 with the new
  cases reported as PASS.
- `shellcheck` clean on the modified test script.
- `git diff` confirms no change to `scripts/lib/deploy-freshness-lib.sh`.

---

### Phase 3: Per-dispatch freshness surface in skill-base.sh [NOT STARTED]

**Goal**: Make the existing comparison fire once per skill/agent dispatch — the granularity at
which a stale instruction file is actually read — without adding anything to a blocking path.

**Tasks**:
- [ ] Confirm the placement hypothesis before editing: verify `skill_preflight_update` is invoked
      once per dispatch by `orchestrate-cycle-plan.sh`'s per-task live-dispatch loop, and that
      `command-gate-in.sh`'s CHECKPOINT 1 fires only once per top-level command. Record the
      confirmation.
- [ ] Source `scripts/lib/deploy-freshness-lib.sh` in `skill-base.sh` using the same
      two-candidate resolution order the file already uses for `common.sh` and
      `task-lookup-lib.sh` (deployed path first, source-store-relative fallback second).
- [ ] Add a small function that computes the stale-extension list via
      `deploy_freshness_stale_names "$SKILL_REPO_ROOT"` and exports it for the dispatch builder
      to reuse, so Phase 4 does not re-derive the call.
- [ ] Call it from `skill_preflight_update` and, when the list is non-empty, emit a loud,
      explicitly-named WARN block to stderr: the stale extension names, the statement that the
      deployed `.claude/` tree for those extensions no longer matches the source store, and the
      redeploy remedy. Never hand-patch guidance.
- [ ] Guarantee the no-abort contract: a missing library, missing `jq`/`git`, an absent or
      unparseable `.claude-extensions.json`, or an empty result each degrade to a silent no-op.
      `skill_preflight_update` must still always return 0 and must still run its extension hook
      and lifecycle event exactly as before on every path.
- [ ] Do NOT touch the `specs/.freshness-warn-streak.json` streak counter from this call site —
      that counter is a consecutive-COMMAND-invocation count owned by `check-deploy-freshness.sh`,
      and incrementing it per dispatch would corrupt its documented meaning.
- [ ] Keep `skill-base.sh` Class C (sourced; sets no shell options) — add no `set` line.

**Timing**: 1.5 hours

**Depends on**: 1, 2

**Verification Tier**: full

**Commit Mode**: per-substep

**Scope Hypothesis**: Research asserts `skill_preflight_update` is the per-dispatch site and that
no additional call site is needed to cover non-orchestrate skill runs. Confirm by grepping live
call sites before editing; if a second per-dispatch entry point exists that bypasses this
function, record it and decide explicitly rather than assuming one site suffices.

**Files to modify**:
- `agent-system/extensions/core/scripts/skill-base.sh` - library sourcing block, new
  stale-names helper, WARN emission inside `skill_preflight_update`

**Verification**:
- `shellcheck` clean on `skill-base.sh` per `context/standards/shell-strict-mode.md`.
- `bash agent-system/extensions/core/scripts/tests/test-skill-base-lifecycle.sh` exits 0.
- `bash agent-system/extensions/core/scripts/tests/run-all.sh` shows no new failures relative to
  a pre-change baseline captured in the same session.
- Sourcing `skill-base.sh` in a shell with `set -e` and calling `skill_preflight_update` against a
  fixture with no `.claude-extensions.json` does not abort the caller.
- No file under any `.claude/**` tree is edited by hand.

---

### Phase 4: Inject the freshness signal into the dispatch brief [NOT STARTED]

**Goal**: Put the detected signal where the spawned agent will actually read it — inside the
dispatch file — following the existing optional-block precedent, so a dispatch with nothing stale
stays byte-identical to one built before this feature existed.

**Tasks**:
- [ ] Read `orchestrate-build-dispatch.sh`'s Stage 3.5 output section and the final block-writing
      brace group to confirm the established optional-block pattern (build a variable; emit only
      when non-empty).
- [ ] Add a Stage 3.5 output that computes the stale-extension list, reusing the helper added in
      Phase 3 rather than re-deriving the library call, and degrading to an empty string on every
      failure mode.
- [ ] Emit a `<deploy-freshness-context>` block into the dispatch file when the list is
      non-empty, placed alongside the other injected context blocks. Content: the stale extension
      names, an explicit statement that documented commands and instructions sourced from those
      extensions' deployed files may be out of date, the instruction to verify against the source
      store before relying on such a command, and the redeploy remedy.
- [ ] State inside the block that a fresh-looking file elsewhere in the same tree does NOT imply
      the tree is current — the partial-staleness trap that caused the observed incident.
- [ ] Explicitly forbid, in the block text, hand-patching the deployed `.claude/**` file as a
      remedy.
- [ ] Confirm by inspection that a build with an empty list produces a dispatch file
      byte-identical to the pre-change output.

**Timing**: 1.0 hours

**Depends on**: 3

**Verification Tier**: interface

**Commit Mode**: per-substep

**Scope Hypothesis**: This phase assumes the Phase 3 helper is reachable from
`orchestrate-build-dispatch.sh` (which already sources or resolves `SKILL_REPO_ROOT`-anchored
scripts). Confirm at implementation time; if it is not reachable without restructuring, fall back
to sourcing `deploy-freshness-lib.sh` directly here with the same two-candidate order and record
the deviation.

**Files to modify**:
- `agent-system/extensions/core/scripts/orchestrate-build-dispatch.sh` - new Stage 3.5 output and
  its conditional emission in the dispatch-file writer

**Verification**:
- `shellcheck` clean on `orchestrate-build-dispatch.sh`.
- A build against a fixture with no stale extensions produces output byte-identical to the
  pre-change build (`diff` of two generated dispatch files).
- A build against a fixture with a stale extension contains the `<deploy-freshness-context>`
  block naming that extension.
- `bash agent-system/extensions/core/scripts/tests/test-orchestrate-build-dispatch.sh` exits 0.

---

### Phase 5: Wiring regression tests [NOT STARTED]

**Goal**: Pin the two new behaviors and their failure modes so a future edit cannot silently
un-wire them, the way the original signal was silently un-actioned.

**Tasks**:
- [ ] Extend `scripts/tests/test-skill-base-lifecycle.sh` with a case asserting that
      `skill_preflight_update` emits the named WARN block to stderr when the fixture repo has a
      stale extension.
- [ ] Add a case asserting silence (no WARN, no abort, return 0) when the fixture has no
      `.claude-extensions.json` at all — the `CANNOTVERIFY` path must never read as an alarm.
- [ ] Add a case asserting the caller is not aborted when the freshness library is absent from
      both candidate paths.
- [ ] Assert `skill_preflight_update` still performs its status write, extension hook, and
      lifecycle event on the stale path exactly as on the clean path.
- [ ] Extend `scripts/tests/test-orchestrate-build-dispatch.sh` with a case asserting the
      `<deploy-freshness-context>` block appears for a stale fixture and is absent for a clean
      one.
- [ ] Assert that no code path added in Phases 3 or 4 writes to
      `specs/.freshness-warn-streak.json`.

**Timing**: 1.5 hours

**Depends on**: 3, 4

**Verification Tier**: local

**Commit Mode**: per-substep

**Scope Hypothesis**: This phase asserts six new test cases across two existing suites. The count
is a hypothesis — confirm at implementation time that each listed behavior is actually
independently assertable in the existing harness shape, and record any case that collapses into
another rather than padding the count.

**Files to modify**:
- `agent-system/extensions/core/scripts/tests/test-skill-base-lifecycle.sh` - new cases
- `agent-system/extensions/core/scripts/tests/test-orchestrate-build-dispatch.sh` - new cases

**Verification**:
- Both suites exit 0 with the new cases reported as PASS.
- `shellcheck` clean on both modified test scripts.
- Temporarily reverting the Phase 3 WARN emission makes the new skill-base case FAIL (the test
  genuinely pins the behavior); restore afterwards.

---

### Phase 6: Measure the per-dispatch cost against the baseline [NOT STARTED]

**Goal**: Satisfy the acceptance requirement that the chosen remedy's wall-clock cost is measured
and shown not to reintroduce the regression that removing the fleet walk from the blocking path
resolved.

**Tasks**:
- [ ] Measure the added per-dispatch cost directly: time `skill_preflight_update` with and
      without the new surface, over at least 5 runs each, and record the delta.
- [ ] Measure a realistic multi-dispatch session: count the dispatches a representative
      `/orchestrate` cycle performs and multiply by the measured per-dispatch delta to get a
      session-level total. Record the dispatch count used and how it was obtained.
- [ ] Contrast the session-level total against the recorded cost profile of the fleet-wide
      consumer walk (~10 minutes across the registered consumer repos) and state the ratio
      explicitly.
- [ ] State the scaling argument with the Phase 1 numbers: cost scales with the checking repo's
      own extension count, never with the registered-consumer count.
- [ ] Append all of this to `specs/200_consumer_deploy_propagation_gap/measurements.md` under a
      clearly separated section, keeping the Phase 1 baseline intact and comparable.
- [ ] If the measured session-level total exceeds a stated ceiling the implementer records up
      front, record the overrun explicitly and flag it rather than accepting it silently.

**Timing**: 1.0 hours

**Depends on**: 3, 4

**Verification Tier**: prose

**Commit Mode**: per-substep

**Scope Hypothesis**: Research asserts the per-invocation cost is ~130ms and that a multi-phase
cycle pays it "a handful of times". Both the per-invocation figure and the dispatch count are
hypotheses — measure both directly and record the observed values, never the research figures.

**Files to modify**:
- `specs/200_consumer_deploy_propagation_gap/measurements.md` - append the per-dispatch and
  session-level measurement section

**Verification**:
- `measurements.md` contains both the Phase 1 baseline and the Phase 6 session-level figures,
  each with the commands used.
- The comparison against the fleet-walk cost profile is stated numerically, not qualitatively.

---

### Phase 7: Document the decision and verify acceptance end to end [NOT STARTED]

**Goal**: Record the recommendation and its rejected alternatives durably in the source store,
then redeploy and confirm the whole chain works against the real consumer repo that exhibited the
defect.

**Tasks**:
- [ ] Extend `agent-system/extensions/core/context/patterns/regeneration-is-manual-only.md`'s
      `## Detecting When You're Stale` section with the new per-dispatch surface: where it fires,
      what it emits, why it is placed at `skill_preflight_update` rather than only at the
      command gate, and the explicit statement that it is non-blocking and always degrades to
      silence.
- [ ] Document the dispatch-brief injection as the orchestrate-mode enhancement layered on top of
      the per-dispatch base layer, including the stated limitation that a directly-invoked skill
      run gets the stderr warning but not the injected block.
- [ ] Record the rejected alternatives with their reasons: a new whole-tree fingerprint
      (redundant — the existing path-scoped per-extension comparison already catches partial
      staleness, pinned by the Phase 2 fixture); hard-blocking or refusing a dispatch on `STALE`
      (would recreate a blocking-gate cost/unactionability problem, and would require a
      `STALE` vs `CANNOTVERIFY` distinction any future implementation must preserve); and
      restoring the fleet-wide walk to a blocking path (explicitly out of scope).
- [ ] Note that the existing consecutive-ignore streak escalation remains the model for a louder
      default if one is wanted later, and that no second streak mechanism was introduced.
- [ ] Write all documentation without any task-number reference, per
      `.claude/rules/no-task-references-in-deliverables.md` — cite filenames and section
      headings instead. This applies to every file outside `specs/**`.
- [ ] Run `shellcheck` across all scripts touched in Phases 2-5 and confirm clean.
- [ ] Run the full core test suite (`scripts/tests/run-all.sh`) and compare against the
      pre-change baseline captured in Phase 3.
- [ ] Redeploy into this repo (`bash .claude/scripts/deploy-headless.sh`) so the deployed
      `.claude/` tree carries the change, and confirm the deploy lands clean.
- [ ] Redeploy into `~/Projects/BimodalLogic` and verify the four previously-cited lean call
      sites there are byte-identical to source (`lean-implementation-agent.md`,
      `lean-implementation-hard-agent.md`, `rules/lean4.md`,
      `skills/skill-lake-repair/SKILL.md`). Fix any divergence by redeploying, never by editing
      the deployed file.
- [ ] Confirm the end-to-end acceptance shape: with a deliberately stale fixture, the stale
      extension is named both on stderr at dispatch preflight and inside the generated dispatch
      file.

**Timing**: 1.0 hours

**Depends on**: 5, 6

**Verification Tier**: full

**Commit Mode**: per-substep

**Scope Hypothesis**: This phase asserts the four lean call sites in `~/Projects/BimodalLogic`
match source after redeploy, and that the full test suite has no pre-existing failures to
disentangle from new ones. Confirm both directly — capture the pre-change `run-all.sh` baseline
before comparing, and diff all four call sites individually rather than spot-checking one (the
spot-check-one reasoning is precisely the trap this task exists to close).

**Files to modify**:
- `agent-system/extensions/core/context/patterns/regeneration-is-manual-only.md` - extend the
  `## Detecting When You're Stale` section with the new tier, the injection layer, and the
  rejected alternatives

**Verification**:
- The pattern doc names the new per-dispatch surface, the dispatch-brief injection, and all three
  rejected alternatives with reasons.
- `grep` for task-number patterns across every file changed outside `specs/**` returns nothing
  (`bash .claude/scripts/check-task-references.sh` clean).
- `shellcheck` clean on every script touched by this task.
- `scripts/tests/run-all.sh` shows no new failures versus the Phase 3 baseline.
- `diff` of all four lean call sites between source and `~/Projects/BimodalLogic/.claude/` is
  empty for all four.
- No `.claude/**` file in any repo was hand-edited (`git status` in both repos, plus review of
  the session's own edit history).

## Testing & Validation

- [ ] `bash agent-system/extensions/core/scripts/tests/test-deploy-freshness.sh` exits 0,
      including the new partial-staleness fixture cases.
- [ ] `bash agent-system/extensions/core/scripts/tests/test-skill-base-lifecycle.sh` exits 0,
      including the WARN, silent-`CANNOTVERIFY`, and missing-library cases.
- [ ] `bash agent-system/extensions/core/scripts/tests/test-orchestrate-build-dispatch.sh` exits
      0, including the present/absent `<deploy-freshness-context>` cases.
- [ ] `bash agent-system/extensions/core/scripts/tests/run-all.sh` shows no new failures versus
      the pre-change baseline.
- [ ] `shellcheck` clean on `skill-base.sh`, `orchestrate-build-dispatch.sh`, and all three
      modified test scripts, per `context/standards/shell-strict-mode.md`.
- [ ] A dispatch built with no stale extension is byte-identical to a pre-change dispatch file.
- [ ] `skill_preflight_update` never aborts a `set -e` caller under any failure mode.
- [ ] `specs/.freshness-warn-streak.json` is not written by any newly added code path.
- [ ] `bash .claude/scripts/check-task-references.sh` clean.
- [ ] All four lean call sites in `~/Projects/BimodalLogic` match source after redeploy.

## Artifacts & Outputs

- `specs/200_consumer_deploy_propagation_gap/plans/01_per-dispatch-freshness-surface.md` (this
  plan)
- `specs/200_consumer_deploy_propagation_gap/measurements.md` (cost baseline and per-dispatch
  measurements)
- `agent-system/extensions/core/scripts/skill-base.sh` (per-dispatch freshness surface)
- `agent-system/extensions/core/scripts/orchestrate-build-dispatch.sh`
  (`<deploy-freshness-context>` injection)
- `agent-system/extensions/core/scripts/tests/test-deploy-freshness.sh` (partial-staleness
  fixture)
- `agent-system/extensions/core/scripts/tests/test-skill-base-lifecycle.sh` (wiring cases)
- `agent-system/extensions/core/scripts/tests/test-orchestrate-build-dispatch.sh` (injection
  cases)
- `agent-system/extensions/core/context/patterns/regeneration-is-manual-only.md` (decision record
  and rejected alternatives)
- `specs/200_consumer_deploy_propagation_gap/summaries/01_*-summary.md` (execution summary)

No `manifest.json` change is expected: every file above is already registered under core's
`provides` entries. If a new file becomes necessary, registering it in
`agent-system/extensions/core/manifest.json` is a required additional step.

## Rollback/Contingency

All changes are additive, confined to the source store, and each phase commits independently, so
rollback is per-phase `git revert` of the relevant commits — no data migration to undo and no
consumer repo left in a half-changed state.

- **If the per-dispatch surface proves too noisy or too costly** (Phase 6 overrun): revert Phase 3
  and Phase 4 commits only. Phase 2's fixture test is independently valuable and stays; it pins
  the partial-staleness property of the existing library regardless of where the check fires.
- **If a `set -e` abort surfaces in real dispatch usage**: revert the Phase 3 commit immediately —
  it is the only change on a lifecycle-critical path — and re-approach with the library call
  moved behind an explicit subshell boundary.
- **If a redeploy into a consumer repo goes wrong**: re-run the deploy; never hand-patch the
  deployed `.claude/` tree, which would mask the very divergence this work exists to detect.
- **If a genuine whole-tree rollback of uncommitted work is needed**, follow
  `context/contracts/recovery.md`'s rollback rung for the exact snapshot-then-rollback invocation
  shape, including its out-of-scope override flag. Do not take a bare precautionary snapshot at
  the start of a phase; an ordinary defensive checkpoint before risky work uses the durable,
  non-reverting `--no-revert` mode instead.
