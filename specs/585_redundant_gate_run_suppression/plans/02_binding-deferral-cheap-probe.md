# Implementation Plan: Task #585

- **Task**: 585 - Make the batch-gate deferral binding and cache repeat gate runs, so the full set runs once per batch
- **Status**: [NOT STARTED]
- **Effort**: 2.75 hours
- **Dependencies**: None
- **Research Inputs**: specs/585_redundant_gate_run_suppression/reports/01_redundant-gate-run-suppression.md, specs/585_redundant_gate_run_suppression/reports/02_binding-deferral-and-cache-adoption.md
- **Artifacts**: plans/02_binding-deferral-cheap-probe.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Mechanism A (`orchestrate-build-dispatch.sh`'s `## Batch Gate Deferral` directive) already narrows
a final implement phase's obligation to a scoped tier, but it gives the dispatched agent no cheap
way to re-confirm green and says nothing against running the complete gate set anyway. This plan
closes that by editing the directive's own emitted text: `--skip-unchanged` is named on the
`verify-deploy.sh --only-gate` invocation as the sanctioned cheap probe, and a short
NO-ADDITIONAL-FULL-SWEEP paragraph names the mutex-queueing cost a redundant sweep imposes on
sibling dispatches and routes the only sanctioned escalation through the existing
UNMAPPABLE CRITERION carve-out. Three consumer documents and the implementer-side agent contract
are brought into sync with the new emitted text, and the whole tree is redeployed. No hook, no
validator, no change to Move 4, and no change to `run-all.sh`, `verify-deploy.sh`, or batch
admission.

### Research Integration

Report 02 resolved all five seed design questions from live code and the plan follows its four
load-bearing conclusions: Mechanism A is prose-only with no enforcement surface worth adding
(Recommendation 3 — no hook); Move 4 is structurally incapable of using the cache because
`deploy_findings_snapshot` unconditionally strips `--skip-unchanged`, so it is untouched
(Recommendation 2); the `.gate-lock` mutex needs no change, since a narrowed `--only` run never
takes it and a cache-hit gate 8 is excluded before `gate8_run` is ever called (Recommendation 5);
and `BUILD_HEAVY_CANDIDATE_TASK_TYPES` / Mode 2 admission stays untouched (Recommendation 4).

**One correction to Recommendation 1, verified at authoring time.** The report proposes emitting
`run-all.sh --only SUITE[,SUITE...] --skip-unchanged`. `tests/run-all.sh` has no such flag: its
argument loop (`agent-system/extensions/core/scripts/tests/run-all.sh:242-302`) ends in a
catch-all `*) echo "ERROR: unknown argument: $1" >&2; exit 2` arm, and `--skip-unchanged` is
parsed only by `verify-deploy.sh:359`. Emitting it on the `run-all.sh` line would hand every
batched implement dispatch an invocation that fails immediately. The flag is therefore applied to
the `verify-deploy.sh --only-gate` invocation ONLY. Adding the flag to `run-all.sh` was rejected:
that file is in sibling task 584's declared `file_scope` for this same cycle, and a narrowed
`run-all.sh --only` run already skips the `specs/.gate-lock` bracket entirely, so it carries none
of the contention the cache fast path exists to relieve.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No `roadmap_path` was provided in this dispatch's delegation context; no roadmap consultation was
performed and no roadmap phases are included.

## Goals & Non-Goals

**Goals**:
- Name `--skip-unchanged` inside Mechanism A's own emitted directive as the sanctioned cheap probe
  for re-confirming a scoped tier, on the one invocation that actually parses it.
- Strengthen the directive's bindingness in prose: state the concrete cost of an additional full
  sweep under a batch, and route the only sanctioned escalation through the existing
  UNMAPPABLE CRITERION carve-out with a recording obligation.
- Keep the four consumer surfaces that restate the directive's invocation shapes in sync with the
  emitted text, and keep the composer's own test suite asserting the new shapes.
- Redeploy so the deployed `.claude/` mirror carries the edited source store.

**Non-Goals**:
- No hook, validator, or mechanical refusal for an additional full sweep (Recommendation 3: no
  predicate exists today that distinguishes a sanctioned escalation from a wasteful sweep).
- No change to Move 4 (`orchestrate-batch-gate.sh`, `deploy_findings_snapshot`) — already
  structurally cache-proof.
- No change to `tests/run-all.sh`, `verify-deploy.sh`, `gate-cache-lib.sh`, or
  `suite-selection-lib.sh` (all in sibling tasks 584/607 territory this cycle).
- No change to `BUILD_HEAVY_CANDIDATE_TASK_TYPES` or Mode 2 co-scheduling admission.
- No work on covering-suite-selector/Gate-8 convergence or gate-corpus completeness (owned
  elsewhere; see report 02's Decisions).

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| A future editor reads the new directive text as endorsing `--skip-unchanged` for Move 4's shared capture | M | L | The edit lives entirely inside the `batch_gate_deferral_flag` block; `deploy_findings_snapshot`'s own unconditional strip is an independent structural safeguard that does not depend on this wording |
| `--skip-unchanged` is emitted onto an invocation that cannot parse it | H | L (now) | Verified at authoring time: only `verify-deploy.sh` parses it; Phase 1's first task re-greps both parsers before editing |
| A stale cache entry returns a false `[SKIP-CACHED]` PASS on a scoped run | M | L | Unchanged exposure: the scoped tier is exactly the invocation shape the cache equivalence suite targets; corpus completeness stays owned elsewhere and is not weakened here |
| `generate-context-line-counts.sh --write` folds a concurrent sibling's context edit into this task's commit | M | M | Phase 2 runs `--check` first and proceeds with `--write` only when the flagged entries are exactly this task's own two; otherwise it hand-corrects only those two values |
| A sibling's in-flight source-store edit makes a shared suite red | M | M | Per this dispatch's territory note: re-read before editing, stage explicit file lists only, and treat a failure outside this task's `Files to modify` as possibly a sibling's edit — confirm against `git log` and report rather than "fixing" it |
| The whole-tree redeploy in Phase 3 collides with a sibling's own regeneration | M | M | Phase 3 declares `__WHOLE_TREE__` so batch admission serializes it; if the deploy is refused on a stale/foreign state, stop and report — the Inter-Cycle Redeploy Checkpoint performs the deploy on the next cycle |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2 | 1 |
| 3 | 3 | 2 |

Phases within the same wave can execute in parallel.

### Phase 1: Emit the cheap probe and the no-extra-sweep obligation [NOT STARTED]

**Goal**: `orchestrate-build-dispatch.sh`'s `## Batch Gate Deferral` block emits
`--skip-unchanged` on the `verify-deploy.sh --only-gate` invocation and carries two new prose
paragraphs (CHEAP PROBE, NO ADDITIONAL FULL SWEEP), with the composer's own test suite asserting
both.

**Tasks**:
- [ ] Re-read `agent-system/extensions/core/scripts/orchestrate-build-dispatch.sh` around the
      `batch_gate_deferral_flag` block before editing (a sibling may have touched it).
- [ ] Re-confirm the flag-parser asymmetry before editing:
      `grep -n -- '--skip-unchanged' agent-system/extensions/core/scripts/verify-deploy.sh agent-system/extensions/core/scripts/tests/run-all.sh`
      must hit `verify-deploy.sh` and miss `run-all.sh`. If `run-all.sh` has since gained the
      flag, add it to that emitted line too and say so in the phase notes; otherwise leave that
      line's text unchanged.
- [ ] Append ` --skip-unchanged` to the emitted `verify-deploy.sh --only-gate N[,M...]` invocation
      line only. Leave the emitted `run-all.sh --only SUITE[,SUITE...]` line unflagged.
- [ ] Insert a `CHEAP PROBE:` paragraph after the existing "record ... that the full set was
      deferred" sentence and before the `UNMAPPABLE CRITERION:` paragraph. It states that
      `--skip-unchanged` returns `[SKIP-CACHED]` immediately for every gate whose declared input
      corpus this dispatch did not touch, making a repeat or exploratory re-check of an already
      green scoped tier cost seconds instead of a battery, and that it applies to every repeat
      check inside the dispatch, not only the first.
- [ ] Insert a `NO ADDITIONAL FULL SWEEP:` paragraph immediately after it, stating that running
      the complete gate set anyway — unflagged, or a second time — is the specific waste this
      directive exists to prevent, because under a multi-task batch each such sweep queues
      single-file behind Gate 8's `specs/.gate-lock` mutex and stalls every sibling dispatch; and
      that the only sanctioned full sweep is the UNMAPPABLE CRITERION carve-out below, which
      requires naming the specific unreachable criterion in the phase's own verification notes.
- [ ] Keep both paragraphs inside the `if [ -n "$resolved_run_all" ] || [ -n "$resolved_verify_deploy" ]`
      branch — the degradation branch (neither entry point resolves) must stay byte-identical,
      since it has no narrowing invocation to probe cheaply.
- [ ] Write no task numbers into any emitted or edited source-store text (rules/no-task-references-in-deliverables.md).
- [ ] Extend Group 19 of `agent-system/extensions/core/scripts/tests/test-orchestrate-build-dispatch.sh`:
      assert the resolved `verify-deploy.sh --only-gate N[,M...] --skip-unchanged` string is
      present, assert `run-all.sh --only SUITE` is present WITHOUT `--skip-unchanged`, and assert
      both new paragraph markers (`CHEAP PROBE:`, `NO ADDITIONAL FULL SWEEP:`) appear in the
      resolved-candidate dispatch and are absent from the degradation-branch dispatch.

**Timing**: 1 hour

**Depends on**: none

**Verification Tier**: local

**Commit Mode**: per-substep

**Scope Hypothesis**: this phase asserts the directive emits exactly two narrowing-invocation
lines, both inside the `batch_gate_deferral_flag` block's resolved-candidate branch. Confirm at
implementation time with
`grep -n -- '--only SUITE\|--only-gate N' agent-system/extensions/core/scripts/orchestrate-build-dispatch.sh`;
if more than two lines match, edit only the ones inside that block and record the discrepancy.

**Tier Justification**: `bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-force-phases.sh,test-orchestrate-build-aux-dispatch.sh,test-orchestrate-build-dispatch.sh,test-orchestrate-context-growth.sh,test-orchestrate-cycle-plan.sh,test-orchestrate-record-decision.sh,test-orchestrate-recover-message-findings.sh,test-orchestrate-unwind-dispatch.sh,test-routing-resolution.sh`
is the verbatim `suite_selection_select` covering set for both files this phase touches.

**Files to modify**:
- `agent-system/extensions/core/scripts/orchestrate-build-dispatch.sh` - append `--skip-unchanged`
  to the emitted `verify-deploy.sh --only-gate` invocation; add the CHEAP PROBE and
  NO ADDITIONAL FULL SWEEP paragraphs inside the resolved-candidate branch
- `agent-system/extensions/core/scripts/tests/test-orchestrate-build-dispatch.sh` - Group 19
  assertions for the new emitted flag, the deliberately unflagged `run-all.sh` line, and both new
  paragraphs (present when resolved, absent in the degradation branch)

**Verification**:
- The `--only` invocation above passes with every named suite green.
- A composed implement dispatch with `--batch-gate-deferral` and resolvable candidates contains
  `verify-deploy.sh --only-gate N[,M...] --skip-unchanged`, `run-all.sh --only SUITE[,SUITE...]`
  with no trailing `--skip-unchanged`, and both new paragraph markers.
- A composed dispatch in the degradation branch is byte-identical to its pre-edit output.

---

### Phase 2: Sync the consumer contracts and the derived line counts [NOT STARTED]

**Goal**: the four documents that restate Mechanism A's invocation shapes describe what the
composer now emits, and the source index's derived `line_count` values stay accurate for the two
context files this phase grows.

**Tasks**:
- [ ] Re-read each target file immediately before editing it.
- [ ] `context/contracts/batch-gate-stage.md` ("Narrowing-invocation paths are resolved, not
      hardcoded", the two-invocation sentence): state that the `verify-deploy.sh --only-gate`
      form carries `--skip-unchanged` as the sanctioned cheap probe and that the `run-all.sh
      --only` form does not, because `run-all.sh` does not parse that flag and a narrowed run
      already bypasses the `specs/.gate-lock` bracket.
- [ ] `context/formats/plan-format.md` ("Batch-aware deferral", the "What the override changes"
      paragraph): update both deploy-target and source-store invocation shapes to match the
      emitted text, and add one sentence that the cheap probe does not relax the
      "`--skip-unchanged` is never a tier" reading already stated for `--skip-slow` and
      `--only`/`--only-gate` — it narrows cost, never the set of checks a phase's criteria
      require.
- [ ] `agents/general-implementation-agent.md` ("Batch Gate Deferral (final phase only)"): name
      the cheap probe for repeat checks and add the no-additional-full-sweep obligation, mirroring
      the directive's own wording, including that an escalation records the unmappable criterion.
- [ ] `context/contracts/phase-closure.md`: read the no-promotion-without-evidence carve-out and
      confirm whether it restates either invocation shape. Edit it only if it does; if it merely
      cross-references, leave it unchanged and say so in the phase notes.
- [ ] Run `bash agent-system/extensions/core/scripts/generate-context-line-counts.sh --check` and
      read the flagged set. If the only flagged entries are `formats/plan-format.md` and
      `contracts/batch-gate-stage.md`, run `--write`. If any other entry is flagged, do NOT run
      `--write`: hand-correct only this task's own two `line_count` values in
      `agent-system/extensions/core/index-entries.json` and report the foreign drift per the
      dispatch's territory note.
- [ ] Stage each file by explicit name; never a directory or glob pathspec.

**Timing**: 1 hour

**Depends on**: 1

**Verification Tier**: local

**Commit Mode**: per-substep

**Scope Hypothesis**: this phase asserts the consumer set is exactly these four documents plus the
derived index. Confirm at implementation time with
`grep -rln -- '--only SUITE\|--only-gate N' agent-system/extensions/core --include=*.md`; edit any
additional document the grep surfaces, or record why it needs none. `phase-closure.md` is listed
conditionally for this reason and is expected to need no edit.

**Tier Justification**: `bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-orchestrate-build-dispatch.sh,test-phase-heading-patterns.sh,test-plan-file-scope-harvest.sh,test-resume-scan-nonconformance.sh,test-lint-agent-contracts.sh,test-lint-agent-contracts-heartbeat.sh,test-orchestrate-cycle-postflight.sh,test-context-reachability.sh,test-deploy-orphans.sh,test-index-entries-schema.sh,test-install-uninstall-extension.sh,test-manifest-scripts-sync.sh,test-roadmap-command-registration.sh,test-lean-challenge-snapshot.sh`
is the verbatim union of `suite_selection_select` over this phase's files, and
`bash <repo_root>/.claude/scripts/verify-deploy.sh --only-gate 3 --skip-unchanged <repo_root>`
(flags before the positional `TARGET`, which is the source-store repository's own root per
plan-format.md's sub-case (b) shape) covers the doc-lint Rule R `line_count` check that no suite
reaches.

**Files to modify**:
- `agent-system/extensions/core/context/contracts/batch-gate-stage.md` - the two-invocation
  sentence gains the cheap probe and the `run-all.sh` asymmetry
- `agent-system/extensions/core/context/formats/plan-format.md` - "Batch-aware deferral"
  invocation shapes plus the never-a-tier sentence
- `agent-system/extensions/core/agents/general-implementation-agent.md` - implementer-side cheap
  probe and no-additional-full-sweep obligation
- `agent-system/extensions/core/context/contracts/phase-closure.md` - conditional; edited only if
  it restates an invocation shape
- `agent-system/extensions/core/index-entries.json` - derived `line_count` for the two context
  entries above (plan-format and batch-gate-stage), regenerated in this same phase because
  doc-lint Rule R (gate 3) fails on a mismatch

**Verification**:
- `bash agent-system/extensions/core/scripts/generate-context-line-counts.sh --check` exits 0.
- The `--only` suite set above is green and the `--only-gate 3` run reports no Rule R finding.
- Each edited document's invocation shapes match the composer's emitted text verbatim
  (`--skip-unchanged` on the `--only-gate` form, absent on the `--only` form).

---

### Phase 3: Redeploy and discharge the complete gate set [NOT STARTED]

**Goal**: the deployed `.claude/` tree carries the edited source store, and the complete gate set
runs green over the result.

**Tasks**:
- [ ] Re-read `git status --short` and confirm every modified path is this task's own; stop and
      report any foreign uncommitted modification rather than proceeding.
- [ ] Run `bash agent-system/extensions/core/scripts/deploy-headless.sh` to regenerate the
      deployed tree from the source store.
- [ ] Confirm the deployed mirror carries the edit:
      `grep -n -- '--only-gate N\[,M\.\.\.\] --skip-unchanged' .claude/scripts/orchestrate-build-dispatch.sh`.
- [ ] Run the complete gate set: `bash .claude/scripts/verify-deploy.sh`.
- [ ] Record the result in the phase notes, including whether this dispatch was itself under a
      `## Batch Gate Deferral` directive (in which case this phase discharges the scoped tier the
      directive names and records the full set as deferred to the batch stage, rather than running
      the sweep here).

**Timing**: 0.75 hours

**Depends on**: 2

**Verification Tier**: full

**Commit Mode**: per-substep

**Files to modify**:
- `__WHOLE_TREE__` - `deploy-headless.sh` regenerates the entire deployed tree
- `agent-system/extensions/core/index-entries.json` - `deploy-headless.sh` runs the line-count
  regenerator before deploying and may correct residual values

**Verification**:
- `bash .claude/scripts/verify-deploy.sh` runs the complete gate set (all gates in
  `gate-registry.data`, no `--only-gate`, no `--skip-slow`, no `--skip-unchanged`) and reports no
  new findings — or, when this dispatch carries a `## Batch Gate Deferral` directive, the scoped
  tier that directive names runs green and the deferral is recorded per
  `context/contracts/phase-closure.md`'s no-promotion-without-evidence carve-out.
- The deployed `.claude/scripts/orchestrate-build-dispatch.sh` contains the new emitted flag and
  both new paragraphs.

---

## Testing & Validation

- [ ] `test-orchestrate-build-dispatch.sh` Group 19 asserts the emitted `--skip-unchanged` on the
      `--only-gate` form and its deliberate absence on the `--only` form.
- [ ] The degradation branch's emitted dispatch is unchanged.
- [ ] `generate-context-line-counts.sh --check` exits 0.
- [ ] Doc-lint (gate 3) reports no new finding.
- [ ] The complete gate set (or the batch-deferred scoped tier, recorded as such) is green.

## Artifacts & Outputs

- Edited `orchestrate-build-dispatch.sh` directive emitting the cheap probe and the
  no-additional-full-sweep obligation.
- Extended Group 19 assertions in `test-orchestrate-build-dispatch.sh`.
- Three (possibly four) synced consumer documents and corrected `index-entries.json` line counts.
- A redeployed `.claude/` tree.
- Implementation summary at `specs/585_redundant_gate_run_suppression/summaries/02_*-summary.md`.

## Rollback/Contingency

Every change is an additive text edit to tracked source-store files; reverting is a per-file
`git revert` or `git checkout` of this task's own commits followed by a redeploy. If the
redeploy in Phase 3 is refused (stale or foreign state), leave the source-store commits in place
and report: the Inter-Cycle Redeploy Checkpoint performs the deploy on the next cycle and
reconciles the task itself. If the directive's new prose proves wrong in practice, the two
inserted paragraphs are self-contained `echo` lines that can be removed without touching the
invocation lines or any consumer document.
