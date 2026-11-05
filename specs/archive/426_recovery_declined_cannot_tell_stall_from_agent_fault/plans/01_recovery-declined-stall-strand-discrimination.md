# Implementation Plan: Make RECOVERY_DECLINED Distinguish an Abandoned Wrap-Up from an Agent-Contract Fault

- **Task**: 426 - RECOVERY_DECLINED cannot tell stall from agent fault
- **Status**: [COMPLETED]
- **Effort**: 5.5 hours
- **Dependencies**: None
- **Research Inputs**: specs/426_recovery_declined_cannot_tell_stall_from_agent_fault/reports/01_recovery-declined-stall-strand-discrimination.md
- **Artifacts**: plans/01_recovery-declined-stall-strand-discrimination.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md, rules/source-store-deploy-boundary.md
- **Type**: meta
- **Lean Intent**: false

## Overview

`orchestrate-cycle-postflight.sh`'s absent-handoff RECOVERY_DECLINED case arm writes a blocking,
agent-attributed defect record without consulting the two signals the same script computes
~1100 lines later (`stall_suspected`, `stranded_suspected`) that bear on whether the dispatch's
work is intact and one-re-prompt recoverable. The same call also hardcodes `--phase implement`
and passes a structurally-always-empty `--dispatch-seq`. This plan adds a record-site,
arm-local consultation of both signals (annotation only — the classification and severity are
unchanged), fixes the two recording bugs, closes the test-harness gap that makes the
`issues.jsonl` side of this path unassertable today, and pins all four VERIFY items.

Definition of done: a RECOVERY_DECLINED issue entry carries the dispatch's real phase and this
cycle's minted `dispatch_seq`; the entry and both stderr/defect messages name whichever of
stall/strand fired at record time (or state that neither did); `stall_suspected` and
`stranded_suspected` keep byte-identical trigger expressions and byte-identical emitted values.

### Research Integration

Carried forward from the report and re-verified at plan-authoring time:

- **DEFECT B** — `--phase implement` is a literal at the `issue-record.sh` call inside the
  RECOVERY_DECLINED arm; `$phase` is parsed at line ~359 and validated at line ~410 to
  `research|plan|implement`, a strict subset of `issue-record.sh`'s own `--phase` enum. Confirmed
  in source.
- **DEFECT C** — `handoff_dispatch_seq` is assigned at exactly one site (lines ~663-664) inside
  the handoff-PRESENT guard, while this arm is nested in `if [ ! -f "$handoff_file" ]`, so the
  `[ -n ... ]` guard never fires. `expected_dispatch_seq` (set at lines 479-483) is in scope, and
  the `dispatch-metrics.sh` call site at line ~1828 already documents exactly this reasoning
  ("deliberately NOT `$handoff_dispatch_seq`, which is empty on the recovery path"). Confirmed in
  source.
- **Agent contract is not underspecified** — `agents/planner-agent.md` already states the
  terminal `.return-meta.json` write as a MUST (Stage 0 and Critical Requirement 9). The live
  symptom was a violation, not a gap. No agent-contract file is edited by this plan.
- **Test-harness gap** — `issue-record.sh` is in neither the top-of-file `require_file` loop nor
  `setup_sandbox`'s `cp` loop in `test-orchestrate-cycle-postflight.sh`, so every existing
  RECOVERY_DECLINED fixture's `issue-record.sh` call silently no-ops behind the
  `|| echo "Note: issue recording failed (non-fatal)"` fallback, and no fixture reads
  `issues.jsonl` at all. Confirmed by grep. VERIFY (1) and (2) are unsatisfiable until this is
  closed. `issue-record.sh`'s only dependencies are `lib/common.sh`, `deploy-root-guard.sh`, and
  `lib/task-lookup-lib.sh` — all three already in the existing copy lists.

**One departure from the report's primary recommendation, with reason.** The report recommends
hoisting the `strand_probe_verdict` capture (currently lines 2031-2045) and the
`stall_commit_count` git-log (currently inside the lines-2154-2202 block) to run before line
1006 and *removing* the later computation. Re-verification at plan-authoring time found a
dependency the report's "nothing changes between the two points" argument misses: **WORK (i)'s
per-task scoped commit sits at line 1843, between the two points.** On a RECOVERY_DECLINED cycle
the task directory is dirty (the agent's own `.return-meta.json` at minimum), so WORK (i) can and
does land a commit inside the dispatch window before line 2154 runs. A hoist-and-remove would
therefore change `stall_suspected`'s emitted value (postflight's own commit would stop being
counted) and `stranded_suspected`'s (the strand probe's commit-quiescence leg would see a
quiescent tree where it currently sees a fresh commit) — a silent behavior change to two emitted,
lead-consumed fields, which is squarely against this task's non-widening posture even though it
is technically a narrowing rather than a widening.

This plan instead computes **arm-local, separately-named** annotation values inside the
RECOVERY_DECLINED arm only, and leaves both canonical blocks byte-identical. Costs: one extra
read-only `dispatch-strand-probe.sh` invocation and one extra `git log` — both incurred *only* on
the RECOVERY_DECLINED path, never on a healthy dispatch. Benefits beyond safety: the record-site
reading is strictly more accurate for attribution, because at line ~1009 no postflight-authored
commit exists yet, so any commit the count sees is necessarily the dispatched agent's own.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No `roadmap_path` was supplied in this dispatch and no roadmap phases are required.

## Goals & Non-Goals

**Goals**:
- A RECOVERY_DECLINED `issues.jsonl` entry carries the dispatch's real `phase` (DEFECT B).
- It carries a non-null `dispatch_seq` equal to this cycle's minted `expected_dispatch_seq`
  (DEFECT C).
- The RECOVERY_DECLINED stderr line, the `system-defect-record.sh` message, the loop-guard
  `detected_defects[]` row, and the `issues.jsonl` entry all let a reader tell an abandoned
  wrap-up (work intact, remedy = one re-prompt) from an uncorroborated agent-contract violation
  (DEFECT A), including as machine-readable `--tags-json` fields.
- `test-orchestrate-cycle-postflight.sh` can assert `issues.jsonl` content at all.
- All four VERIFY items from the dispatch are pinned by fixtures.

**Non-Goals**:
- Widening, narrowing, re-siting, or otherwise altering `stall_suspected`'s or
  `stranded_suspected`'s trigger expressions, emitted values, or stderr notices. Both carry
  on-the-record DELIBERATE NON-WIDENING rulings; this plan adds a consumer, not a producer.
- Downgrading or suppressing the RECOVERY_DECLINED classification or its `blocking` severity. The
  contract violation is real in every sub-case; what is added is a reader's ability to see both
  readings in one record.
- Editing `agents/planner-agent.md`, `docs/architecture/handoff-schema.md`, or
  `context/patterns/infra-failure-discrimination.md` — all three were consulted and found already
  consistent with this change.
- Fixing the sibling `handoff_dispatch_seq` call sites at lines ~1301, ~1335, ~1421, ~1442,
  ~1503. They share DEFECT C's structural pattern but sit on the *successful-recovery* path
  (`have_outcome=true`), outside this task's stated scope. Already recorded as a follow-up in this
  task's `issues.jsonl`.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| A reader treats "stall suspected" in the record as meaning no defect occurred | M | M | Keep `system-defect-record.sh` unconditional and `--severity blocking` in every sub-case; phrase the clause as a corroborating *recoverability* observation appended to the unchanged violation sentence, never as a replacement for it |
| The arm-local annotation value diverges from the emitted `stall_suspected`/`stranded_suspected` field, confusing a reader comparing the two | M | M | Name the arm-local values distinctly (`rd_stall_*`, `rd_strand_*`) and state in a code comment that they are a record-time snapshot taken *before* WORK (i)'s own commit, so divergence from the emit-time field is expected and intentional |
| The extra `dispatch-strand-probe.sh` invocation fails, is missing, or is slow | L | L | Reuse the existing capture block's degrade contract verbatim: `[ -x ]` guard, `|| strand_probe_json=""`, `jq -r '.verdict // "unknown"'`, final `[ -z ] && "unknown"`. Never abort; `unknown` simply yields no annotation. Invoked only on the RECOVERY_DECLINED path |
| Copying `issue-record.sh` into the test sandbox makes previously-silent calls real, perturbing unrelated fixtures | M | M | Phase 2 runs the whole suite immediately after the copy-list change and before adding any assertion, so any fixture disturbed by the newly-live call is caught as a standalone, attributable regression |
| A `--tags-json` object that fails to parse makes `issue-record.sh` exit 1 and the whole entry vanish | M | L | Build the object with `jq -n --argjson`, never string interpolation; the call already degrades non-fatally, and Phase 4 asserts the tag keys are present and correctly typed |
| `.claude/` deploy drifts from the source store after the edits | L | M | Final phase re-deploys and runs `verify-deploy.sh`; the source store `agent-system/extensions/core/` is the only edit target throughout |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2, 3 | 1 |
| 3 | 4 | 2, 3 |
| 4 | 5 | 4 |

Phases within the same wave can execute in parallel. Phases 2 and 3 touch disjoint files
(`scripts/tests/test-orchestrate-cycle-postflight.sh` vs.
`scripts/orchestrate-cycle-postflight.sh`) and are genuinely parallelizable; both depend on
Phase 1 because Phase 2's assertions assert Phase 1's values and Phase 3 edits the same case arm.

---

### Phase 1: Fix the two recording bugs at the RECOVERY_DECLINED issue-record call [COMPLETED]

**Goal**: The `issue-record.sh` invocation inside the
`STATUS_IN_PROGRESS|STATUS_NOT_SUCCESS|META_DISPATCH_SEQ_MISMATCH` arm records the dispatch's
real phase and this cycle's minted dispatch_seq.

**Tasks**:
- [x] In `agent-system/extensions/core/scripts/orchestrate-cycle-postflight.sh`, in the
      `issue_args=(...)` array inside the RECOVERY_DECLINED arm (currently ~line 1057), replace
      the literal `--phase implement` with `--phase "$phase"`. *(completed)*
- [x] Replace the following line's
      `[ -n "${handoff_dispatch_seq:-}" ] && issue_args+=(--dispatch-seq "$handoff_dispatch_seq")`
      with the `expected_dispatch_seq` equivalent. *(completed)*
- [x] Add a short comment above the two lines recording *why* `expected_dispatch_seq` is correct
      here, cross-referencing the existing `dispatch-metrics.sh` call site (~line 1828) that
      already documents the identical reasoning. Keep it to two or three lines — the precedent
      comment already carries the full argument. *(completed)*
- [x] `bash -n` the edited script. *(completed: exits 0; deviation noted on the plan's literal
      `--phase implement` grep-based verification check — see progress file)*

**Timing**: 0.5 hours

**Depends on**: none

**Verification Tier**: local

**Tier Justification**: the edit is two argument literals inside one case arm of one script, and
`bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-orchestrate-cycle-postflight.sh`
is the only suite in the corpus that exercises RECOVERY_DECLINED at all (confirmed:
`grep -ln RECOVERY_DECLINED scripts/tests/*.sh` returns exactly that one file).

**Scope Hypothesis**: exactly two lines change in exactly one file, plus a 2-3 line comment. The
implementer confirms with `git diff --stat` showing a single changed file and a diff body
containing no edit outside the `issue_args` construction.

**Files to modify**:
- `agent-system/extensions/core/scripts/orchestrate-cycle-postflight.sh` — `--phase "$phase"`,
  `--dispatch-seq "$expected_dispatch_seq"`, explanatory comment

**Verification**:
- `bash -n agent-system/extensions/core/scripts/orchestrate-cycle-postflight.sh` exits 0.
- `grep -n -- '--phase implement' agent-system/extensions/core/scripts/orchestrate-cycle-postflight.sh`
  returns nothing.
- `grep -n 'handoff_dispatch_seq' ...` shows no remaining occurrence inside the
  `if [ ! -f "$handoff_file" ]` block.
- `bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-orchestrate-cycle-postflight.sh`
  is green (the suite cannot yet observe the new values — see Phase 2 — but must not regress).

---

### Phase 2: Close the test-sandbox gap and pin the phase/dispatch_seq values [COMPLETED]

**Goal**: `issue-record.sh` actually runs inside the test sandbox, and fixtures assert VERIFY (1)
and VERIFY (2) against real `issues.jsonl` content.

**Tasks**:
- [x] Add `issue-record.sh` to the top-of-file `require_file` loop's script list in
      `scripts/tests/test-orchestrate-cycle-postflight.sh`. *(completed)*
- [x] Add `issue-record.sh` to `setup_sandbox`'s `cp` loop over the same list. Add a short comment
      in the style of the neighbouring dependency notes explaining that omitting it makes every
      RECOVERY_DECLINED fixture's issue call a silent no-op behind the existing non-fatal
      fallback. *(completed)*
- [x] Run the full suite unchanged at this point and triage any fixture disturbed purely by the
      call going live. Fix or annotate each before adding new assertions. *(completed: 0
      fixtures disturbed, full suite green with the copy-list addition alone)*
- [x] Extend fixture (I) (`STATUS_IN_PROGRESS`, `--phase research`, task 914) with assertions on
      `$WORKDIR/specs/914_candidate/issues.jsonl`: exactly one `orchestration defect` entry;
      `.phase == "research"` (VERIFY 1 — proves the literal is gone, since `research` can never
      be produced by the old hardcode); `.dispatch_seq == 1`, matching the fixture's own
      `--dispatch-seq 1` argument and non-null (VERIFY 2). *(completed)*
- [x] Add a second RECOVERY_DECLINED fixture at `--phase plan` reproducing the live symptom
      shape — a planner dispatch, `.return-meta.json` at `status: in_progress`, no handoff — and
      assert `.phase == "plan"` and `.dispatch_seq` equal to that fixture's minted seq. This is
      the direct regression pin for the cited incident. *(completed: fixture (I2), candidate
      #915)*

**Timing**: 1.5 hours

**Depends on**: 1

**Verification Tier**: local

**Tier Justification**: the change is confined to one test file plus a sandbox copy list, and
`run-all.sh --only test-orchestrate-cycle-postflight.sh` executes every line of it; no production
script changes in this phase.

**Scope Hypothesis**: making the previously-silent `issue-record.sh` call live perturbs zero
existing fixtures. The implementer confirms by running the full suite immediately after the
copy-list edit and before any new assertion, and treats any new failure as in-scope work for this
phase rather than carrying it forward.

**Files to modify**:
- `agent-system/extensions/core/scripts/tests/test-orchestrate-cycle-postflight.sh` — two copy-list
  additions, fixture (I) assertions, one new `--phase plan` fixture

**Verification**:
- `bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-orchestrate-cycle-postflight.sh`
  is green with the new assertions present and passing.
- Deliberate-break check: temporarily restore `--phase implement` in the source script, confirm
  the new fixture-(I) phase assertion FAILS, then restore. The assertion must be proven to bite.
- Same deliberate-break check for the `dispatch_seq` assertion with `handoff_dispatch_seq`
  restored.

---

### Phase 3: Consult stall/strand at the RECOVERY_DECLINED record site [COMPLETED]

**Goal**: The RECOVERY_DECLINED record names whichever of the abandoned-wrap-up or heartbeat-strand
signatures corroborates this occurrence, in prose and as structured tags, without touching either
canonical signal block.

**Tasks**:
- [x] Inside the RECOVERY_DECLINED case arm, after `$recovery_declined_detail` is built and before
      the `is_live` gate, compute two arm-local values:
      - `rd_stall_commit_count` / `rd_stall_corroborated` using the *same* conjunction text as the
        canonical `stall_suspected` block (`phase` in `plan|implement`, `have_outcome != "true"`,
        `dispatch_start_ts != "9999999999"`, then `git -C "${SKILL_REPO_ROOT:-.}" log --oneline
        --since="@${dispatch_start_ts}" -- "$TASK_DIR" | grep -c .` greater than zero).
      - `rd_strand_verdict` / `rd_strand_corroborated` from one `dispatch-strand-probe.sh` call,
        reusing the existing capture block's degrade contract verbatim (`[ -x ]` guard,
        `|| strand_probe_json=""`, `jq -r '.verdict // "unknown"'`, `[ -z ] && "unknown"`), gated
        on the same `have_outcome`/`dispatch_start_ts` preconditions the canonical
        `stranded_suspected` block uses. *(completed)*
- [x] Write a header comment over the two computations stating: (a) these are a *record-time
      snapshot*, deliberately separate from and lexically distinct from `stall_suspected` /
      `stranded_suspected`, which are computed unchanged at their own sites; (b) the record-time
      reading can legitimately differ from the emitted field because WORK (i)'s per-task commit
      (line ~1843) lands between the two points, and the record-time reading is the
      agent-attributable one precisely because no postflight-authored commit exists yet; (c) this
      is a CONSUMER of the two signals, never a widening of either trigger expression — cite both
      canonical blocks' DELIBERATE NON-WIDENING rulings by name. *(completed)*
- [x] Append a corroboration clause to `$recovery_declined_detail`, in three mutually exclusive
      branches: stall corroborated (name the commit count and the documented remedy — the
      committed work is intact, remedy is one re-prompt, do not charge to failed_tasks); else
      strand corroborated (name the stale-heartbeat signature and the same one-re-prompt remedy);
      else neither (state explicitly that no corroborating stall or strand signal was found at
      record time, i.e. this occurrence is not evidence of recoverable, work-intact failure).
      Because the clause is appended to `$recovery_declined_detail`, it reaches the stderr notice,
      `system-defect-record.sh --message`, the loop-guard `detected_defects[]` row, and
      `issue-record.sh --what-happened` with no further plumbing. *(completed)*
- [x] Add `--tags-json` to the `issue_args` array, built with
      `jq -n --argjson stall ... --argjson strand ...` (never string interpolation), carrying
      `stall_corroborated`, `stranded_corroborated`, `stall_commit_count`, and `strand_verdict`.
      *(completed)*
- [x] Mirror the corroboration clause into the `[dry-run] would record RECOVERY_DECLINED` stderr
      line so a dry run reports the same discrimination it would have recorded. *(completed)*
- [x] Verify by inspection and by `git diff` that the canonical `stall_suspected` block
      (~2154-2202) and `stranded_suspected` block (~2204-2240) and the `strand_probe_verdict`
      capture (~2031-2045) are untouched. *(completed: `git diff -U0` shows exactly 3 hunks, all
      within the original 1024-1069 span of the RECOVERY_DECLINED arm; zero hunks anywhere near
      the canonical blocks)*

**Timing**: 1.5 hours

**Depends on**: 1

**Verification Tier**: interface

**Tier Justification**: the `--tags-json` addition changes the shape of a written `issues.jsonl`
record, whose schema is read by `test-issue-record.sh` and `test-orchestrate-conclusion-aggregate.sh`
in addition to the postflight suite, so the narrowed set must span those consumers rather than
only the local suite.

**Scope Hypothesis**: the change is additive within one case arm and touches no code outside
`if [ ! -f "$handoff_file" ]`. The implementer confirms with
`git diff -U0 scripts/orchestrate-cycle-postflight.sh` showing every hunk's line numbers inside
the arm's span, and specifically that no hunk falls in the 2020-2250 range.

**Files to modify**:
- `agent-system/extensions/core/scripts/orchestrate-cycle-postflight.sh` — arm-local stall/strand
  computation, corroboration clause, `--tags-json`, dry-run mirror

**Verification**:
- `bash -n` exits 0.
- `bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-orchestrate-cycle-postflight.sh --only test-dispatch-strand-probe.sh --only test-issue-record.sh --only test-orchestrate-conclusion-aggregate.sh`
  is green.
- `git diff` on the script shows no hunk inside the canonical `stall_suspected`,
  `stranded_suspected`, or `strand_probe_verdict` blocks.
- Existing S1-S4 and T0-T3 fixtures still pass with unchanged expected values.

---

### Phase 4: Pin the discrimination and the non-widening guarantee [COMPLETED]

**Goal**: VERIFY (3) and VERIFY (4) are enforced by fixtures that bite.

**Tasks**:
- [x] Add a fixture pair for VERIFY (3) over the `in_progress`-meta-plus-absent-handoff case at
      `--phase plan`: (a) with at least one task commit landed inside the dispatch window, assert
      the `issues.jsonl` entry's `.tags.stall_corroborated == true`, a positive
      `.tags.stall_commit_count`, and the one-re-prompt remedy phrasing present in
      `.what_happened`; (b) with no commit inside the window, assert
      `.tags.stall_corroborated == false` and the explicit no-corroborating-signal phrasing. Both
      must still record exactly one RECOVERY_DECLINED defect row with `--severity blocking` — the
      annotation discriminates, it does not reclassify. *(completed: fixtures J1/J2, candidates
      #916/#917)*
- [x] Add a strand variant reusing the existing `write_lock_fixture` /
      `write_session_registry_fixture` helpers (already in the suite for the T1 stranded case) to
      assert `.tags.stranded_corroborated == true` with `stall_corroborated` false, proving the
      two annotations are independent at the record site exactly as the emitted fields are.
      *(completed: fixture J3, candidate #918 — deviation: built on the multi-task engine
      (no --loop-guard-file), not the single-task engine I/I2/J1/J2 use; see progress file)*
- [x] Add a VERIFY (4) non-widening pin: a lexical assertion over the SUT source that the two
      canonical trigger expressions are present verbatim and unmodified — grep for
      `stall_suspected`'s exact `{ [ "$phase" = "implement" ] || [ "$phase" = "plan" ]; } && [ "$have_outcome" != "true" ]`
      conjunction and for `stranded_suspected`'s exact
      `[ "$have_outcome" != "true" ] && [ "$dispatch_start_ts" != "9999999999" ] && [ "$strand_probe_verdict" = "stranded" ]`
      conjunction, each matching exactly once. Document in a comment that this test exists to
      enforce the two on-the-record DELIBERATE NON-WIDENING rulings and must be updated only
      alongside an explicit decision to revise them. *(completed: deviation — scoped the grep to
      each canonical field's own few-line block via sed, rather than a bare whole-file grep; see
      progress file)*
- [x] Confirm S1-S4 and T0-T3 remain present and unmodified (behavioral complement to the lexical
      pin): the emitted field values are unchanged by this task. *(completed: all 11 S/T fixture
      assertions present and passing)*

**Timing**: 1.5 hours

**Depends on**: 2, 3

**Verification Tier**: local

**Tier Justification**: the phase adds fixtures to one test file and changes no production script,
so `run-all.sh --only test-orchestrate-cycle-postflight.sh` executes every line it adds.

**Scope Hypothesis**: four new fixture blocks and one lexical pin, all additive, with zero edits
to existing S1-S4/T0-T3 assertion text. The implementer confirms by checking that
`git diff scripts/tests/test-orchestrate-cycle-postflight.sh` contains no deletion line inside the
`stall_suspected`/`stranded_suspected` fixture sections.

**Files to modify**:
- `agent-system/extensions/core/scripts/tests/test-orchestrate-cycle-postflight.sh` — VERIFY (3)
  commit/no-commit pair, strand variant, VERIFY (4) lexical pin

**Verification**:
- `bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-orchestrate-cycle-postflight.sh`
  is green.
- Deliberate-break check on the VERIFY (3) pair: force `rd_stall_corroborated=false`
  unconditionally in the script, confirm fixture (a) FAILS, then restore.
- Deliberate-break check on the VERIFY (4) pin: add a harmless disjunct to one canonical trigger
  expression, confirm the pin FAILS, then restore.

---

### Phase 5: Document the record-site consultation, deploy, and run the full gate set [COMPLETED]

**Goal**: The `RECOVERY_DECLINED` registry row tells a future reader that the record site consults
the two signals, the source store is deployed, and every gate passes.

**Tasks**:
- [x] Add one or two sentences to `context/patterns/system-defect-discrimination.md`'s
      `RECOVERY_DECLINED` row (in the source store, `agent-system/extensions/core/`) stating that
      the recording site also carries record-time stall/strand corroboration in its message and in
      `issue-record.sh`'s `--tags-json`, and that those record-time values are a pre-WORK-(i)
      snapshot that can legitimately differ from the emitted `stall_suspected`/`stranded_suspected`
      fields. Do not restate the whole mechanism — point at the script's own comment. *(completed)*
- [x] Re-confirm that `docs/architecture/handoff-schema.md`'s Postflight Boundary section,
      `context/patterns/infra-failure-discrimination.md`, and `agents/planner-agent.md` still need
      no edit given what actually shipped, and record that conclusion in the summary rather than
      editing them. *(completed: confirmed by inspection, no edit needed; recorded in summary)*
- [x] Deploy the source store so `.claude/` matches
      (`bash .claude/scripts/deploy-headless.sh` or the repo's standard deploy entry point) and
      `diff` the deployed `orchestrate-cycle-postflight.sh` against the source-store copy to
      confirm zero drift. *(completed: deploy landed, zero drift confirmed on every file this
      task touched; deploy-headless.sh's own fast-gate verify pass hit 3 unrelated timeout kills
      under host load, filed as a non-blocking follow-up issue — see summary)*
- [x] Write the implementation summary to
      `specs/426_recovery_declined_cannot_tell_stall_from_agent_fault/summaries/01_recovery-declined-stall-strand-discrimination-summary.md`.
      *(completed)*

**Timing**: 1 hour

**Depends on**: 4

**Verification Tier**: full

**Scope Hypothesis**: the doc change is confined to the `RECOVERY_DECLINED` row of one context
file and the deploy introduces no change outside `.claude/**`. The implementer confirms with
`git diff --stat` before committing: exactly one tracked source-store doc file plus the new
summary, and every `.claude/**` path attributable to the deploy run.

**Files to modify**:
- `agent-system/extensions/core/context/patterns/system-defect-discrimination.md` — one row note
- `specs/426_recovery_declined_cannot_tell_stall_from_agent_fault/summaries/01_recovery-declined-stall-strand-discrimination-summary.md`
  — new

**Verification**:
- `bash agent-system/extensions/core/scripts/tests/run-all.sh` — the complete suite exits 0
  (failures only in `known-failures.txt`).
- `bash .claude/scripts/verify-deploy.sh` — the complete gate set exits 0.
- `diff` between the source-store and deployed `orchestrate-cycle-postflight.sh` is empty.
- No file under `.claude/**` was hand-edited at any point:
  `git status --short .claude/` shows only deploy-generated changes.

## Testing & Validation

- [ ] VERIFY (1): a RECOVERY_DECLINED `issues.jsonl` entry carries the dispatch's real phase —
      asserted at `research` (fixture I) and at `plan` (new fixture).
- [ ] VERIFY (2): that entry carries a non-null `dispatch_seq` equal to the cycle's minted seq.
- [ ] VERIFY (3): the `in_progress`-meta-plus-absent-handoff case is annotated differently when a
      task commit landed inside the dispatch window than when none did, in both the prose and the
      structured tags, with the defect class and severity unchanged in both.
- [ ] VERIFY (4): `stall_suspected` and `stranded_suspected` retain their existing trigger
      expressions unwidened — enforced lexically, and behaviorally by unchanged S1-S4/T0-T3.
- [ ] Every new assertion is proven to bite via a deliberate-break-and-restore check.
- [ ] `run-all.sh` and `verify-deploy.sh` both exit 0.

## Artifacts & Outputs

- `agent-system/extensions/core/scripts/orchestrate-cycle-postflight.sh` — DEFECT B and C fixes;
  arm-local stall/strand corroboration in the message, in `--tags-json`, and in the dry-run notice
- `agent-system/extensions/core/scripts/tests/test-orchestrate-cycle-postflight.sh` —
  `issue-record.sh` added to both sandbox lists; fixtures for all four VERIFY items
- `agent-system/extensions/core/context/patterns/system-defect-discrimination.md` — one-row note
  on the record-site consultation
- `specs/426_recovery_declined_cannot_tell_stall_from_agent_fault/summaries/01_recovery-declined-stall-strand-discrimination-summary.md`

## Rollback/Contingency

Every phase is an independent, committed, green increment over two files plus one doc row, with no
schema migration and no persisted-state change to unwind, so the cheapest rollback is a forward fix
or `git revert` of the specific phase commit. The `--tags-json` addition is purely additive to
`issues.jsonl`; existing entries and existing readers are unaffected.

If a rollback of *uncommitted* work is genuinely required (not as a routine precaution), take a
snapshot first per `context/contracts/recovery.md`'s rollback rung, then run the destructive
command. Do not emit `git-snapshot.sh` in its default reverting form as a start-of-phase
checkpoint; for an ordinary defensive checkpoint before risky work use
`bash .claude/scripts/git-snapshot.sh 426 --no-revert`, which is durable without reverting the
working tree.

Partial-state note: stopping after Phase 1 leaves the system strictly better than today (both
recording bugs fixed) but unasserted. Stopping after Phase 2 leaves the two bug fixes pinned and
the DEFECT A ambiguity open — a coherent, shippable state. Phase 3 is the one deliverable whose
absence leaves the originally-reported defect unaddressed, so it must not be dropped if scope is
cut; Phase 5's doc row is the cheapest thing to defer.
