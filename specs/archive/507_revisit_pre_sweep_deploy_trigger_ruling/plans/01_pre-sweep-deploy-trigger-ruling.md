# Implementation Plan: Task #507

- **Task**: 507 - Re-adjudicate the declined pre-postflight-sweep deploy trigger against a measured whole-cycle gate cost
- **Status**: [COMPLETED]
- **Effort**: 1.75 hours
- **Dependencies**: explicit_lint_fixture_test_subject_resolution, warn_plan_size_exceeds_cycle_budget (both declared territory edges on the touched file; both recorded as discharged at research time)
- **Research Inputs**: specs/507_revisit_pre_sweep_deploy_trigger_ruling/reports/01_pre-sweep-deploy-trigger-readjudication.md
- **Artifacts**: plans/01_pre-sweep-deploy-trigger-ruling.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

The deliverable is a **ruling in prose**, not a mechanism. The durable anchor
`agent-system/extensions/core/context/patterns/batch-orchestration-guardrails.md`'s subsection
"A Pre-Postflight-Sweep Deploy Trigger: Evaluated, Intentionally Not Built" already records the
declined trade on four grounds (a)-(d) and closes by asking that a later pass re-derive the
reasoning rather than re-propose the trigger without it. This task is that later pass, and the
research phase has already performed the re-derivation and reached a **REAFFIRM** verdict. The
implementation is therefore a single appended, dated amendment paragraph in the source store, a
redeploy, and a documentary gate run — no code change, no new call site, no change to either
existing trigger site.

Two phases: Phase 1 re-confirms the figures the amendment will quote and applies the amendment to
the source-store file; Phase 2 redeploys the tree and discharges the full gate set.

### Research Integration

The research report's key findings carried into this plan:

- **Grounds (a) and (b) re-derived against the current tree: unchanged.** Move 2 still issues
  every dispatch in one message and Move 3 still runs only after all of them return
  (`skills/skill-orchestrate/SKILL.md`); `scripts/tests/test-lint-deploy-caller-wrap.sh` still
  hard-asserts exactly `{orchestrate-cycle-plan.sh, command-gate-out.sh}` as the genuine
  deploy-caller set; the baseline-relative branches, confirmation/attribution filters,
  `.deployed_critical_paths` idempotence guard, and durable `deploy_ledger_*` ledger are all
  present in the shape the record assumes.
- **One sharpening of ground (b)**: `command-gate-out.sh` carries no durable ledger at all, so a
  third call site would need the *full* mechanism stack, not whichever subset an existing site
  happens to carry. The record understates rather than overstates the structural cost.
- **Ground (c) priced corpus-wide**: 68 of 396 completed `meta` tasks (~17.2%) have hit this gate
  at least once; of 59 measurable paused-to-reconciled deltas, 57 resolved inside the same
  `/orchestrate` session at a median of 336s (mean 415s, range 105s-2,726s). The 2 remaining
  deltas are cross-session resume gaps a Move 2/Move 3 trigger structurally cannot close, yet
  they hold ~94% of the total measured deferral time.
- **Ruling: REAFFIRM**, with a dated amendment note appended after the "(d) The verdict."
  paragraph. The report's `## Recommendations` section carries the exact amendment prose, ready to
  apply.

**Premise re-validation (the dispatch's Carried-Figure Discipline block).** Each extracted line
was checked at planning time, and the result is stated here even where it only confirms the
description unchanged:

| Carried claim | Check performed at planning time | Result |
|---|---|---|
| Source store is the edit target; redeploy via `deploy-headless.sh` | `.claude-extensions.json` present; `.claude/scripts/deploy-headless.sh` resolves; source path mirrors deployed path | CONFIRMED unchanged |
| Commit `7f3cf35b1` discharged a deferred completion via the Inter-Cycle Redeploy Checkpoint | `git log --oneline -1 7f3cf35b1` -> `task 419: complete implementation (post-deploy reconcile)` | CONFIRMED present, message matches the reconcile shape the description asserts |
| The subsection and its four grounds (a)-(d) exist, with the closing "a later pass ... should re-derive" sentence | Direct read of the file at the subsection | CONFIRMED present; four grounds intact, closing sentence intact |
| `test-lint-deploy-caller-wrap.sh` asserts exactly two genuine callers | Direct read of the negative assertion block | CONFIRMED: `-eq 2` plus both basename greps, unchanged |
| Territory edges: two open records declare the touched file | Both slugs present in `specs/state.json` and `specs/archive/state.json`; research recorded both as completed/discharged | CONFIRMED as described; re-check at admission time per the dispatch's own instruction |
| Frequency figures (1 of 7; 4 of 8; and the report's 68/396, 59 deltas, median 336s) | NOT re-derived at planning time | DEFERRED to Phase 1, which re-runs both derivations before the figures enter a durable deliverable |

The last row is the one open premise, and Phase 1 exists to close it.

### Prior Plan Reference

No prior plan. `plans/` was empty at planning time; this is the first plan for this record.

### Roadmap Alignment

No `roadmap_path` was provided in the delegation context and no roadmap flag was set, so no
roadmap phases are included and no roadmap item is claimed.

## Goals & Non-Goals

**Goals**:

- Record the REAFFIRM ruling in the durable anchor as an appended, dated amendment note, with
  every quoted figure naming its own derivation.
- Preserve grounds (a)-(d) byte-for-byte so a future reader can still see exactly what was
  weighed.
- Redeploy the tree so the amended guidance reaches the deployed `.claude/` copy, and discharge
  the documentation gates over the touched file.

**Non-Goals**:

- Implementing the pre-sweep deploy trigger. The ruling is REAFFIRM; there is nothing to build.
  (Had the ruling been SUPERSEDE, implementation would still have been out of this record's
  scope by the dispatch's own instruction.)
- Weakening, bypassing, or re-siting the completion-deploy gate. It refused correctly.
- Removing, duplicating, or relocating the Inter-Cycle Redeploy Checkpoint. It is the current,
  functioning answer and worked as documented.
- Proposing a cold-start/resume-latency mechanism to address the two cross-session outliers. The
  report flags that as a side observation only; it is outside this record's question.
- Rewriting the subsection as a draft lineage, or deleting any of the four grounds.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| A quoted figure has drifted since the research pass (new tasks completed, new gate firings) | M | M | Phase 1 re-runs both derivations before the amendment is written and writes the re-derived values, not the report's values, if they differ |
| The amendment's dated note trips `check-record-versioning.sh` (its sanctioned exemption matches the `**Amended by** <doc>, <date>:` shape, which the proposed `**Amended <date> —**` opener does not) | M | L | The proposed prose contains no BLOCKING or ADVISORY pattern from `scripts/lib/record-version-patterns.sh` (no page-level version label, no `supersede`+`vN` pairing, no `no longer`/`previously`/`formerly`/`used to`/`withdrawn`), so no exemption is needed. Phase 1 runs the scoped lint and, if it does flag, reshapes the note's opener to the sanctioned form rather than removing the dated-amendment framing |
| Citing the figures' source by naming the research artifact path would embed a task number in a file under `agent-system/**` | H | M | The amendment names its *derivation* (the issues.jsonl class query and the `git log --all` commit-message pairing), never the `specs/**` artifact path. Phase 1 runs `check-task-references.sh` scoped to the file to confirm |
| A sibling task edits the same file between the re-read and the commit (shared file territory; three siblings dispatched this cycle) | M | L | Declared siblings' `file_scope` sets do not include this file. Phase 1 and Phase 2 each re-read the file immediately before touching it, stage only this task's own hunks by explicit file list, and stop and report any foreign modification |
| Redeploy regenerates the whole tree and so touches far more than this task's declared scope | M | H (by design) | Phase 2 declares the `` `__WHOLE_TREE__` `` sentinel so the whole-tree claim is visible to batch admission; the deployed tree is gitignored, so nothing outside the one source file is staged |
| An unrelated pre-existing gate failure is mistaken for a regression from a prose-only edit | L | M | Phase 2 compares any failure against the touched file's own surface; a failure in a file outside this task's `file_scope` is treated as possibly a sibling's in-flight edit and reported, not repaired here |

## Implementation Phases

**Dependency Analysis**:

| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2 | 1 |

Phases within the same wave can execute in parallel.

### Phase 1: Re-confirm the quoted figures and append the dated REAFFIRM amendment [COMPLETED]

**Goal**: The subsection carries an appended, dated amendment note stating the REAFFIRM ruling
and citing re-confirmed figures with their derivations, with grounds (a)-(d) untouched.

**Tasks**:

- [x] Re-read `agent-system/extensions/core/context/patterns/batch-orchestration-guardrails.md`
      at the subsection "A Pre-Postflight-Sweep Deploy Trigger: Evaluated, Intentionally Not
      Built" (around line 1475 at planning time) and confirm, before editing: the heading is
      present, grounds (a), (b), (c), and (d) are each present, and the closing sentence asking a
      later pass to re-derive the reasoning is present. If the subsection is absent or the
      grounds have been edited since research time, STOP and report rather than reconstructing
      it — the durable record is the carrier of this ruling and must not be guessed at.
      *(completed: heading and all four grounds confirmed present at line 1475, closing sentence
      intact, before any edit)*
- [x] Re-derive the frequency figure: query every `issues.jsonl` under `specs/**` and
      `specs/archive/**` for `class == "stale deploy or source-store boundary"` with
      `phase == "implement"` and a completion-deploy-gate refusal in `what_happened`, count
      distinct task numbers, and divide by the completed `meta`-task population from
      `specs/archive/state.json` plus `specs/state.json`. Record the numerator, denominator, and
      percentage actually observed.
      *(completed: 68 distinct tasks of 397 completed meta tasks (389 archive + 8 active) ≈
      17.1%, re-derived by direct query)*
- [x] Re-derive the wall-clock cost figures: pair `task {N}: orchestration paused (cycle {C})`
      against `task {N}: complete implementation (post-deploy reconcile)` by task number across
      `git log --all`, and record the sample count, min, median, mean, and max, plus the count and
      magnitudes of any cross-session outliers.
      *(completed: 62 paired deltas, 60 same-session by `Session:` trailer match (median 334s,
      mean 470s, range 105s-4,136s), 2 cross-session outliers (28,387s, 287,534s) holding ~92% of
      total deferral time)*
- [x] Compare both re-derived results against the report's figures (68/396 ~17.2%; 59 deltas,
      57 same-session, median 336s, mean 415s, range 105s-2,726s; 2 outliers at 28,387s and
      287,534s holding ~94% of total deferral time). State the comparison explicitly in the
      phase's verification notes even when it only confirms them unchanged. Where a figure has
      drifted, the amendment quotes the **re-derived** value, not the report's.
      *(completed: see Phase 1 Verification Notes below — denominator 396→397, deltas 59→62,
      same-session 57→60, mean 415s→470s, outlier share 94%→92%, all drift attributable to 3
      additional tasks completing between research and this dispatch; conclusion unchanged)*
- [x] Append the amendment paragraph immediately after the "(d) The verdict." paragraph, using
      the prose in the research report's `## Recommendations` section ("Proposed amendment text")
      as the base, substituting any re-derived figure that differs and setting the date to the
      actual amendment date rather than the report's. Do not edit, reorder, reword, or delete any
      of grounds (a)-(d), and do not add supersession or draft-lineage framing.
      *(completed: amendment appended, dated 2026-11-11, with re-derived figures substituted)*
- [x] Confirm the amendment names the *derivation* of each figure (the issues.jsonl class query;
      the `git log --all` commit-message pairing) and never a `specs/**` artifact path — a path
      citation would embed a task number in a file under `agent-system/**`.
      *(completed: amendment cites the issues.jsonl class query and the git log --all
      commit-message/Session-trailer pairing; no specs/** path or task number appears)*
- [x] Run `bash .claude/scripts/check-task-references.sh agent-system/extensions/core/context/patterns/batch-orchestration-guardrails.md`
      and confirm exit 0.
      *(completed: exit 0, "0 unexempted task-reference occurrences")*
- [x] Run `bash .claude/scripts/check-record-versioning.sh agent-system/extensions/core/context/patterns/batch-orchestration-guardrails.md`
      and confirm zero BLOCKING findings. If the dated opener is flagged, reshape it to the
      sanctioned dated-amendment-note form rather than dropping the date or the amendment
      framing.
      *(completed: 0 BLOCKING, 21 pre-existing ADVISORY findings elsewhere in the file; none in
      the new paragraph; exit 0)*
- [x] Run `bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-deploy-baseline-lib.sh,test-deploy-ledger-lib.sh,test-gate-out-self-attribution.sh`
      and confirm green.
      *(completed: 3 passed, 0 failed, 0 skipped)*
- [x] Read the staged diff and confirm every changed hunk lies inside the appended prose
      paragraph, with no hunk inside grounds (a)-(d) or anywhere else in the file.
      *(completed: single hunk, lines 1513-1534, entirely inside the new paragraph)*
- [x] Commit, staging only this one file by explicit path. *(completed)*

**Timing**: 1 hour

**Depends on**: none

**Verification Tier**: prose

**Scope Hypothesis**: this phase asserts (i) exactly one file is modified
(`agent-system/extensions/core/context/patterns/batch-orchestration-guardrails.md`, matching the
record's declared `file_scope`) and (ii) the report's frequency and wall-clock figures. Confirm
(i) with `git status --short` showing that single path modified before staging, and (ii) by the
two re-derivation tasks above, whose observed values supersede the report's in the amendment text
if they differ.

**Tier Justification**: `suite_selection_select` maps this path to exactly
`test-deploy-baseline-lib.sh`, `test-deploy-ledger-lib.sh`, `test-gate-out-self-attribution.sh`,
and those three suites plus the diff read-through fully cover a prose-only append that adds no
executable surface to a guidance document.

**Files to modify**:

- `agent-system/extensions/core/context/patterns/batch-orchestration-guardrails.md` - append a
  dated amendment paragraph after the "(d) The verdict." paragraph of the
  "A Pre-Postflight-Sweep Deploy Trigger: Evaluated, Intentionally Not Built" subsection,
  recording the REAFFIRM ruling and the re-confirmed figures with their derivations; grounds
  (a)-(d) left byte-for-byte unchanged.

**Verification**:

- The subsection still contains grounds (a), (b), (c), and (d) with their original text, plus the
  closing "a later pass ... should re-derive" sentence.
- The appended paragraph states the ruling explicitly, is dated, and every figure it quotes names
  the derivation that produced it.
- `check-task-references.sh` and `check-record-versioning.sh`, each scoped to the touched file,
  report no blocking findings.
- The three selected suites pass.
- Diff read-through shows every changed hunk inside the appended prose only.

**Phase 1 Verification Notes (re-derivation comparison against the research report's figures)**:

| Figure | Report (research time) | Re-derived (this dispatch) | Changed? |
|---|---|---|---|
| Frequency numerator/denominator | 68 / 396 | 68 / 397 | Denominator +1 (one more `meta` task completed between research and this dispatch) |
| Frequency percentage | ~17.2% | ~17.1% | Negligible drift |
| Paused-to-reconciled deltas (count) | 59 | 62 | +3 (three sibling tasks in this batch — 554, 555, 589 — completed their own reconcile since research time and now pair) |
| Same-session resolutions | 57 | 60 | +3, same cause |
| Same-session median | 336s | 334s | Negligible drift |
| Same-session mean | 415s | 470s | Increased by the 3 newly-paired deltas, still minutes-scale |
| Same-session range | 105s-2,726s | 105s-4,136s | Widened at the top end; still two orders of magnitude below the cross-session outliers |
| Cross-session outliers | 28,387s and 287,534s | 28,387s and 287,534s | Unchanged — same two tasks, same magnitudes |
| Outlier share of total deferral time | ~94% | ~92% | Negligible drift |

All drift is attributable to three additional tasks (554, 555, 589 — co-dispatched siblings in
this same `/orchestrate` batch) completing their paused-to-reconciled cycle between the research
pass and this implementation dispatch, not to any methodological discrepancy. Every re-derived
figure confirms the report's qualitative conclusions unchanged: ~17% gate-trigger frequency,
minutes-scale median same-session resolution, and a dominant (>90%) share of total measured
deferral time attributable to two cross-session outliers a Move 2/Move 3 trigger could not
address. The amendment quotes the re-derived values per this phase's own task list.

Documentary gates run and observed green in this dispatch:
- `check-task-references.sh` (scoped): exit 0, 0 unexempted occurrences.
- `check-record-versioning.sh` (scoped): exit 0, 0 BLOCKING (21 pre-existing ADVISORY findings
  elsewhere in the file, none in the new paragraph).
- `run-all.sh --only test-deploy-baseline-lib.sh,test-deploy-ledger-lib.sh,test-gate-out-self-attribution.sh`:
  3 passed, 0 failed, 0 skipped.
- Staged-diff read-through: one hunk, entirely inside the appended paragraph; grounds (a)-(d)
  byte-for-byte unchanged.

---

### Phase 2: Redeploy the tree and discharge the full gate set [COMPLETED]

**Goal**: The deployed `.claude/` copy carries the amended subsection, and the complete gate set
has been run and observed green over the amended tree.

**Tasks**:

- [x] Re-read the touched source file to confirm Phase 1's amendment is still present and no
      foreign modification has landed since. If a foreign commit or uncommitted foreign
      modification is observed, check `git log` to confirm it is not this task's own work, then
      STOP and report rather than proceeding.
      *(completed: `git status --short` clean for the file; `git log` shows the tip is this
      task's own phase-1 commit `eb18383fd`; no foreign modification)*
- [x] Run `bash .claude/scripts/deploy-headless.sh` to regenerate the deployed tree from the
      source store.
      *(completed, with a deviation — see Phase 2 Verification Notes below: deploy landed but
      the inline fast-gate pass reported `RESULT=landed_verify_red` on an unrelated gate-10
      timeout, root-caused and worked around per the deviation note)*
- [x] Confirm the deployed copy
      `.claude/context/patterns/batch-orchestration-guardrails.md` carries the amendment
      paragraph and the four unchanged grounds (a content check, not a timestamp check).
      *(completed: `diff` against the source-store file is byte-identical; both the amendment
      and all four grounds are present in the deployed copy)*
- [x] Run the complete gate set, `bash .claude/scripts/verify-deploy.sh`, and confirm green. Do
      not substitute `--skip-slow`, `--only-gate`, or any other narrowing for this run.
      *(completed via this dispatch's own Batch Gate Deferral directive rather than the
      unqualified full run — see Phase 2 Verification Notes below for the scoped discharge and
      why the deferral applies)*
- [x] If a gate fails, determine whether the failing surface is this task's own touched file. A
      failure in a file outside this record's `file_scope` is reported as possibly a sibling's
      in-flight edit, not repaired here.
      *(completed: the one failure observed, gate 10's 60s timeout on
      `validate-state.sh --deep specs/state.json`, is outside this record's `file_scope` —
      root-caused directly below, not repaired here)*
- [x] Record, in the phase's verification notes, that the full gate set was run in this dispatch
      and observed green (never trusted on sight). *(completed — see below)*

**Timing**: 0.75 hours

**Depends on**: 1

**Verification Tier**: full

**Files to modify**:

- `__WHOLE_TREE__` - this phase invokes whole-tree regeneration via `deploy-headless.sh`, so the
  reserved sentinel declares the whole-tree claim for batch admission. No real path outside the
  declared source file is edited by hand; the regenerated `.claude/` tree is a gitignored deploy
  artifact.

**Verification**:

- `bash .claude/scripts/deploy-headless.sh` completes without error.
- The deployed `.claude/context/patterns/batch-orchestration-guardrails.md` contains the
  amendment paragraph and grounds (a)-(d).
- `bash .claude/scripts/verify-deploy.sh` — the complete gate set, every gate it aggregates — runs
  in this dispatch and is observed green.
- The completion-deploy gate and the Inter-Cycle Redeploy Checkpoint are both untouched: no edit
  landed in `orchestrate-cycle-plan.sh`, `command-gate-out.sh`, `verify-deploy.sh`, or
  `test-lint-deploy-caller-wrap.sh`, confirmed by `git status --short` and the staged diff.

**Phase 2 Verification Notes**:

- `deploy-headless.sh` was run twice. Both runs reported `the deploy itself landed, but the tree
  fails verification (fast gates)` / `RESULT=landed_verify_red`, with exactly one failing check
  both times: `gate10 (gate10_run) exceeded its 60s timeout and was killed` — gate 10 is
  `specs/state.json schema validation (validate-state.sh --deep)`. Direct re-run of
  `bash .claude/scripts/validate-state.sh --deep specs/state.json` outside the 60s inline-gate
  timeout completed in 68.2s wall-clock and reported `STATE VALIDATION PASSED WITH WARNINGS`
  (20 passed, 7 pre-existing warnings unrelated to this file, 0 failed). The failure is a
  **timeout artifact under this batch's current concurrent write load** (several sibling tasks
  dispatched in this same `/orchestrate` cycle are concurrently writing to the shared
  `specs/state.json`), not a correctness defect, and `specs/state.json` is not a file this
  record's `file_scope` touches by hand (it is only touched by the mechanical per-phase
  heartbeat). Per this phase's own task list and the dispatch's territory-reporting instruction,
  this is reported here rather than repaired — the deploy itself landed correctly (confirmed by
  the byte-identical diff below), and gate 10's own content check passes once given the time it
  actually needs.
- `diff agent-system/extensions/core/context/patterns/batch-orchestration-guardrails.md
  .claude/context/patterns/batch-orchestration-guardrails.md` is empty (exit 0): the deployed
  copy is byte-identical to the source-store file, carrying the amendment and all four grounds.
- **Batch Gate Deferral applied**: this dispatch's own dispatch file (`.dispatch/12.md`) carries
  a `## Batch Gate Deferral` section instructing the final phase (this one, declared
  `**Verification Tier**: full`) to discharge against a scoped narrowing covering the files this
  phase actually touched, rather than independently running the unqualified full
  `verify-deploy.sh` sweep — the full sweep still runs exactly once for the whole batch at the
  end of the `/orchestrate` invocation and is attributed back to this task via `modified_files`.
  The files this phase actually touched are the one context-store markdown file (via the
  Phase 1 edit, redeployed here) and the mechanically-regenerated
  `agent-system/extensions/core/index-entries.json` line-count entry for it — no executable
  surface. The narrowing run was `bash .claude/scripts/verify-deploy.sh --only-gate 3,4,5` (gate
  3 doc-lint, gate 4 task-reference lint — both repo-wide — and gate 5 manifest-driven
  declared-vs-deployed parity plus content-hash equality across all loaded extensions): **PASS
  — 4 check(s), 0 failure(s)**. This is the scoped discharge recorded per the directive; the
  unrelated gate-10 timeout above is not among gates 3/4/5 and does not affect this discharge.
- No mechanism file changed: `git status --short` for `orchestrate-cycle-plan.sh`,
  `command-gate-out.sh`, `verify-deploy.sh`, and `test-lint-deploy-caller-wrap.sh` is empty
  (clean) throughout this phase.

---

## Testing & Validation

- [ ] Grounds (a)-(d) of the subsection are byte-for-byte unchanged from their pre-amendment
      state.
- [ ] The subsection states the ruling (REAFFIRM) explicitly and carries a dated amendment note.
- [ ] Every figure quoted in the amendment names its source derivation, and no figure is asserted
      without one.
- [ ] No `specs/**` path and no task number appears anywhere in the amended file
      (`check-task-references.sh`, scoped).
- [ ] No unexempted record-versioning language appears in the amended file
      (`check-record-versioning.sh`, scoped, zero BLOCKING).
- [ ] The three suites `suite_selection_select` maps this path to all pass.
- [ ] The complete gate set (`verify-deploy.sh`) passes over the redeployed tree.
- [ ] No mechanism file changed: the completion-deploy gate, the Inter-Cycle Redeploy Checkpoint,
      and `test-lint-deploy-caller-wrap.sh`'s two-caller assertion are all exactly as found.

## Artifacts & Outputs

- `agent-system/extensions/core/context/patterns/batch-orchestration-guardrails.md` — amended
  subsection carrying the REAFFIRM ruling, the dated amendment note, the re-confirmed figures with
  their derivations, and all four original grounds.
- The regenerated deployed `.claude/` tree (gitignored; not a committed artifact).
- One implementation summary at `summaries/01_pre-sweep-deploy-trigger-ruling-summary.md`,
  produced at completion per the standard lifecycle, recording the ruling, the re-derived figures,
  and the comparison against the research figures.

## Rollback/Contingency

The entire change is one appended prose paragraph in one file, so rollback is a single revert of
Phase 1's commit followed by a redeploy — no schema change, no state migration, no call-site
change to unwind.

- **If Phase 1's re-derivation contradicts the report's figures materially** (for instance, the
  frequency is far higher than ~17%, or the same-session median is no longer minutes): do NOT
  silently write the REAFFIRM note with new numbers that undercut it. Stop, record the
  contradiction, and set `user_decision` on the return metadata — a REAFFIRM-versus-SUPERSEDE flip
  is the user's call, not an implementation detail, and a SUPERSEDE ruling's implementation is
  explicitly outside this record's scope.
- **If the subsection or its grounds are missing or altered**: stop and report. The ruling has no
  other durable carrier, and reconstructing the grounds from the research report's paraphrase
  would destroy exactly the record a future reader needs.
- **If Phase 2's gate run fails on this task's own surface**: revert Phase 1's commit, redeploy to
  restore the deployed tree, and re-apply the amendment with the gate's complaint addressed.
- **If Phase 2's gate run fails outside this record's `file_scope`**: leave the amendment in
  place, report the failure as possibly a sibling's in-flight edit, and do not attempt a repair
  in this record.
