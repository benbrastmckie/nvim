# Implementation Plan: Task #543

- **Task**: 543 - Tell the re-prompted dispatch to distrust the error count it inherited from the interrupting context
- **Status**: [IMPLEMENTING]
- **Effort**: 2.75 hours
- **Dependencies**: 534 (declared in state.json; live status is `completed` — satisfied, not blocking)
- **Research Inputs**: specs/543_stall_reprompt_distrust_inherited_error_count/reports/01_distrust-inherited-error-count.md
- **Artifacts**: plans/01_distrust-inherited-error-count.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

The stall/strand re-prompt remedy orders foreground re-verification but never says where the
resumer's failure inventory comes from, so a resumer handed a partial error count from the
interrupting context can reconcile against that number and stop early. This plan adds one
obligation — the re-run's own output is the sole inventory, any inherited count is unverified and
non-exhaustive — to the canonical "Loop obligation" list in
`agent-system/extensions/core/docs/architecture/orchestrate-state-machine.md` and to three of the
four remedy-emission sites in `agent-system/extensions/core/scripts/orchestrate-cycle-postflight.sh`,
then pins the new clause with a content assertion in
`agent-system/extensions/core/scripts/tests/test-orchestrate-cycle-postflight.sh` and propagates
everything to `.claude/**` by deploy. Four phases, strictly sequential: doc first (it is the text
the relay prompt is actually built from), then script prose, then test, then deploy plus full gate.

### Research Integration

The research report mechanically re-derived all four `REMEDY:` emission sites (`grep -n "REMEDY:"`
returns exactly four lines: 1072, 1074, 2374, 2414), confirmed the doc anchor, and produced
concrete wording for every site. Three findings shape this plan directly:

1. The doc's "Loop obligation" list — not the script notices — is the text
   `skill-orchestrate/SKILL.md`'s relay builds the re-prompt from; `SKILL.md` defers to it by name
   ("full instructions in orchestrate-state-machine.md's 'Abandoned Wrap-Up'") and therefore needs
   no edit and is correctly outside this task's `file_scope`. The doc edit is the one with a causal
   path to the actual re-prompt text.
2. The `stranded_suspected` notice (line ~2414) already defers to the stall mechanism by name
   ("same mechanism as `stall_suspected`") instead of restating remedy steps inline, so it inherits
   the addition by reference. It is deliberately left unchanged, with the reason recorded — the
   dispatch's acceptance criterion (2) explicitly permits this, provided the reason is stated.
3. The phrase `unverified and non-exhaustive` is confirmed absent from both the script and the doc
   today, so it is safe as the shared substance anchor across script and doc and as the new test's
   grep target with no false-positive collision.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No `roadmap_path` was provided in this dispatch; no roadmap consultation performed.

### Premise Re-Validation (Carried-Figure Discipline)

Every trigger-class figure in the dispatch description was checked against live state before
planning:

| Carried claim | Live check | Result |
|---------------|-----------|--------|
| Four remedy-emission sites, two per detector | `grep -n "REMEDY:"` over the source-store script | **Confirmed unchanged** — exactly four matches at lines 1072, 1074, 2374, 2414, wordings verbatim as described |
| Doc's "Loop obligation" list carries four instructions | Read of `orchestrate-state-machine.md` lines 1165-1180 | **Confirmed unchanged** — four numbered items; item 1 foreground re-run, item 2 attribution, neither naming the inventory's provenance |
| `#770 postflight writes detail-free blocking issue entry` is `not_started` | `specs/state.json` | **STALE** — the migrated record is task 534 here and its live status is `completed`. The dependency edge is satisfied; the residual obligation is to read its landed diff in the shared region, not to wait |
| Cross-repo overlap list (three named records in `~/.config/nvim`) | Re-derived from `specs/state.json` in this repository | **Superseded by migration** — this record now lives in `~/.config/nvim`, so those records are same-repo, not cross-repo. Live overlap re-derived below under Risks |

One carried figure is deliberately *not* reproduced anywhere in this plan's edits: the measured
one-versus-eight count. It is evidence for the change, not content of it — see Goals/Non-Goals.

## Goals & Non-Goals

**Goals**:
- The canonical "Loop obligation" list states that the resumer derives its failure inventory solely
  from its own foreground re-run, treats any inherited count/list/"only N remain" claim as
  unverified and non-exhaustive, and does not stop on that count being reached or cleared.
- Both stall-flavoured emission sites in `orchestrate-cycle-postflight.sh` carry the addition; the
  strand-flavoured `recovery_declined_detail` carries it too, in short form.
- Script-side and doc-side wordings agree on substance via one shared phrase.
- A test case asserts the new clause's *content* in the emitted stall notice, not its non-emptiness.
- Every edit lands in the source store; `.claude/**` changes only by deploy.

**Non-Goals**:
- Editing `skill-orchestrate/SKILL.md` — it defers to the doc by name and is outside `file_scope`.
- Adding the clause to the `stranded_suspected` notice (reasoned exclusion; see Phase 2).
- Changing any detector's firing logic, `verdict`, `persisted_status`, or `failed_tasks`
  bookkeeping. This is a prose change to advisory/diagnostic text and to one canonical doc list.
- Reproducing the originating measurement, the originating task number, the issue `entry_id`, or
  the domain particulars of the interrupting context in any edited file — all three edited files
  lie outside `specs/**`.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Editing the `recovery_declined_detail` corroboration block (lines ~1045-1078) without reading the recently-landed classification/dedup work in the same region silently reverts it | H | M | Phase 1 reads `git log -p` for the recent commits touching that region before any edit; Phase 2 edits only the two `REMEDY:` string tails, never the surrounding branch logic |
| A concurrent writer on the shared test file — task 476 (`isolate_seven_red_gate8_shell_suites`) is live at status `implementing` and claims `test-orchestrate-cycle-postflight.sh` | H | M | Phase 1 checks `git status --short` under `agent-system/extensions/core/scripts/tests/` and re-derives the live claimant set from `specs/state.json` before Phase 3 touches the file; if a live uncommitted edit is present, coordinate (append a new assertion block only, never restructure) rather than racing |
| Adjacent not-started records claim all three files (notably task 570 `stall_signal_counts_unattributed_commits`, plus 501/519/551/609 on the script and test file) and could collide later | M | M | This plan touches only string tails and one doc list, leaving every branch condition and fixture intact, so a later record's edits compose rather than conflict; the overlap set is re-derived at implement time, not trusted from here |
| Inserting a fifth item into the "Loop obligation" list leaves the same doc's downstream sentence ("carrying the four instructions above") asserting a stale count | M | H | Phase 1 fixes that sentence in the same phase and the same commit as the insertion — it is the only in-repo reference asserting the list's item count (`grep -rn "four instructions\|four-item\|four obligations" agent-system/extensions/core/` returns exactly one hit) |
| A test assertion that passes vacuously (e.g. matching text already present for another reason) | M | L | The anchor phrase is confirmed absent from both files today; Phase 3 additionally runs a negative control — temporarily point the assertion at a sentinel phrase, observe the case go red, revert — before accepting it |
| Script and doc wordings drifting apart, which is the defect this record exists to avoid reproducing | H | L | One shared phrase (`unverified and non-exhaustive`) is used verbatim at every site; Phase 2 verifies by grep that it appears in both files |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2 | 1 |
| 3 | 3 | 2 |
| 4 | 4 | 3 |

Phases within the same wave can execute in parallel. This plan is a strict chain: the script prose
must match an already-settled doc wording, the test must assert against an already-present clause,
and the deploy must propagate an already-complete source-store state.

---

### Phase 1: Ground the Edit Surface and Amend the Canonical Loop Obligation [COMPLETED]

**Goal**: Confirm the edit surface mechanically, read the landed state of recent work in the shared
region, and insert the new obligation into the doc list the re-prompt text is actually built from.

**Tasks**:
- [x] Enumerate the emission sites mechanically:
      `grep -n "REMEDY:" agent-system/extensions/core/scripts/orchestrate-cycle-postflight.sh`.
      Record the line numbers and the decision taken for each (needed verbatim by acceptance
      criterion (1) and by the completion summary). Do not trust this plan's line numbers.
      *(completed: 4 matches at lines 1072, 1074, 2374, 2414 — unchanged from the plan's citation)*
- [x] Read the landed diff of recent work in the `recovery_declined_detail` corroboration block:
      `git log --oneline -8 -- agent-system/extensions/core/scripts/orchestrate-cycle-postflight.sh`,
      then `git log -p -3 -- <that file>` restricted to the ~1045-1078 region, so Phase 2's edits
      compose with the classification/dedup logic already there.
      *(completed: region is settled; the three mutually exclusive `rd_stall_corroborated`/
      `rd_strand_corroborated` branches are intact and unambiguous)*
- [x] Re-derive the live claimant set for these three files from `specs/state.json` (any record not
      `completed`/`abandoned` whose `file_scope` names one of them) and run `git status --short`.
      If a live writer holds uncommitted edits in the test file, note it and plan Phase 3 as an
      append-only addition.
      *(completed: several not_started tasks claim the files, but `git status --short` on the
      three target paths was empty — no live uncommitted edit to coordinate around)*
- [x] Insert a new item 2 into the "Loop obligation" numbered list in
      `agent-system/extensions/core/docs/architecture/orchestrate-state-machine.md` (list currently
      at lines ~1165-1180), renumbering the existing items 2-4 to 3-5 and leaving their substance
      untouched. Wording:

      2. Treat any error count, error list, or "only N failures remain" claim arriving with the
         re-prompt, or recoverable from the interrupting context, as unverified and non-exhaustive —
         a lower bound at best, never a stopping condition. The re-run's own output in step 1 is the
         sole failure inventory; completion is that re-run reporting clean (or a documented
         exclusion), never agreement with an inherited count.

- [x] Update the coupled count reference in the same doc's "Where this actually runs" paragraph
      (currently "carrying the four instructions above") so it matches the list's new item count.
      *(completed: now reads "carrying the five instructions above")*
- [x] Confirm the inserted prose cites only durable anchors and carries no task-number reference, no
      record-versioning language, no measured counts, and no domain particulars of any past run; it
      must read as what a resumer does, never as narration of a past run.
      *(completed: `check-task-references.sh` and `check-record-versioning.sh` report 0 blocking
      findings for this file)*

**Timing**: 0.75 hours

**Depends on**: none

**Verification Tier**: local

**Tier Justification**: the edit is markdown prose in one doc with no executable consumer, so
`check-task-references.sh` and `check-record-versioning.sh` over that one file, plus a grep
confirming the list now numbers 1-5 and no "four instructions" reference survives, cover it
completely.

**Scope Hypothesis**: exactly four `REMEDY:` emission sites exist in the script, and exactly one
in-repo sentence asserts the Loop obligation list's item count. Confirm with
`grep -n "REMEDY:" <script>` (expect 4 matches) and
`grep -rn "four instructions\|four-item\|four obligations" agent-system/extensions/core/`
(expect 1 match, in this same doc) before editing; if either count differs, widen the edit and
record the deviation via `issue-record.sh`.

**Files to modify**:
- `agent-system/extensions/core/docs/architecture/orchestrate-state-machine.md` - insert the new
  Loop obligation item, renumber the following items, fix the coupled item-count sentence

The deployed mirror `.claude/docs/architecture/orchestrate-state-machine.md` derives from this file
and is regenerated — never hand-edited — in Phase 4. It is deliberately not listed as a file to
modify here: hand-authoring it would violate acceptance criterion (5), and re-adding deployed-mirror
entries to this task's `file_scope` would reverse a deliberate decision recorded in the record's own
migration provenance.

**Verification**:
- `grep -n "unverified and non-exhaustive" agent-system/extensions/core/docs/architecture/orchestrate-state-machine.md`
  returns the new item.
- The "Loop obligation" list reads 1,2,3,4,5 with no duplicate or skipped number, and the former
  items 1-4 are intact in substance.
- `grep -rn "four instructions\|four-item\|four obligations" agent-system/extensions/core/` returns
  no hit referring to this list.
- `bash .claude/scripts/check-task-references.sh` and
  `bash .claude/scripts/check-record-versioning.sh` report no new finding for this file.

---

### Phase 2: Carry the Addition into the Script-Side Remedy Prose [COMPLETED]

**Goal**: Make three of the four emission sites say, in substance, what the doc list now says, and
record the reasoned exclusion for the fourth.

**Tasks**:
- [x] Extend the `stall_suspected` notice (currently line ~2374) with the full-form clause, inserted
      between the foreground-re-run parenthetical and the artifact-closing clause:
      `... -- never await a harness notification), to derive its failure inventory solely from that
      re-run's own output -- treating any error count or list carried over from the interrupting
      context as unverified and non-exhaustive, a lower bound at best and never a stopping condition
      -- and to close every phase and write all three artifacts before returning. ...`
      *(completed: inserted verbatim at line 2374)*
- [x] Extend the stall-flavoured `recovery_declined_detail` (currently line ~1072) with the short
      form: `REMEDY: one re-prompt, foreground verification with the failure inventory derived
      solely from that re-run -- any inherited count is unverified and non-exhaustive -- do NOT
      charge to failed_tasks without that re-prompt.`
      *(completed: inserted verbatim at line 1072)*
- [x] Extend the strand-flavoured `recovery_declined_detail` (currently line ~1074) with the short
      form: `REMEDY: one re-prompt at the same dispatch_seq, with the failure inventory derived
      solely from that re-run -- any inherited count is unverified and non-exhaustive -- do NOT
      charge to failed_tasks without that re-prompt.`
      *(completed: inserted verbatim at line 1074)*
- [x] Leave the `stranded_suspected` notice (currently line ~2414) unchanged, and write the reason
      down for the completion summary: its own text routes the reader into the one-re-prompt relay
      by name rather than restating remedy steps inline, so it inherits the addition from the stall
      notice and the doc list; duplicating the clause would create a second copy to keep in sync.
      *(completed: left unchanged; deferral to "same mechanism as stall_suspected" confirmed still
      present)*
- [x] Verify no branch condition, variable, or surrounding logic in the `rd_stall_corroborated` /
      `rd_strand_corroborated` conditional was altered — only the quoted string tails.
      *(completed: `git diff` confirms only the three quoted string tails changed)*
- [x] Confirm the edited prose carries no task-number reference, no record-versioning language, and
      no measured count or domain particular.
      *(completed: `check-task-references.sh` and `check-record-versioning.sh` report 0 blocking
      findings for this file)*

**Timing**: 0.75 hours

**Depends on**: 1

**Verification Tier**: local

**Tier Justification**: the change is confined to string literals inside existing `echo` and
variable-assignment statements, so `bash -n` on the script plus
`bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-orchestrate-cycle-postflight`
(the only suite that reads these strings) covers the whole edit.

**Scope Hypothesis**: exactly three of the four sites receive the clause, leaving the
`stranded_suspected` notice as the single reasoned exclusion. Confirm after editing with
`grep -c "unverified and non-exhaustive" <script>` (expect 3) and by re-reading the strand notice to
confirm its "same mechanism as stall_suspected" deferral is still present — if that deferral has
been removed by other work, the exclusion's rationale no longer holds and the fourth site must
receive the clause too.

**Files to modify**:
- `agent-system/extensions/core/scripts/orchestrate-cycle-postflight.sh` - add the distrust clause
  to the `stall_suspected` notice and to both `recovery_declined_detail` remedy tails

The deployed mirror `.claude/scripts/orchestrate-cycle-postflight.sh` derives from this file and is
regenerated by deploy in Phase 4, never hand-edited, for the same reason recorded under Phase 1.

**Verification**:
- `grep -c "unverified and non-exhaustive" agent-system/extensions/core/scripts/orchestrate-cycle-postflight.sh`
  returns 3, at the three intended lines.
- `bash -n agent-system/extensions/core/scripts/orchestrate-cycle-postflight.sh` exits 0.
- `bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-orchestrate-cycle-postflight`
  reports zero failures (existing cases still green).
- `git diff` on the script shows changes only inside quoted strings — no condition, assignment
  target, or control flow touched.
- The script's and the doc's clauses agree on substance: both say the re-run's own output is the
  sole inventory and an inherited count is unverified and non-exhaustive.

---

### Phase 3: Pin the Clause with a Content Assertion in the Suite [COMPLETED]

**Goal**: Make the suite fail if the distrust clause disappears from the emitted stall notice.

**Tasks**:
- [x] Locate the existing `stall_suspected (S1)` case (currently ~line 3577) and confirm its
      `run_sut` call already captures `LAST_STDERR` from a fixture that produces the stall notice —
      no new fixture is needed.
      *(completed: `run_sut` captures `LAST_STDERR` unconditionally; S1's existing fixture already
      reaches the notice-emitting branch)*
- [x] Append an additional assertion block immediately after S1's existing pass/fail block, reusing
      the same captured `$LAST_STDERR` and following the suite's established
      `if echo "$LAST_STDERR" | grep -q "<phrase>"` convention:

      ```bash
      if echo "$LAST_STDERR" | grep -q "unverified and non-exhaustive"; then
        common_test_pass "stall_suspected (S1b): the re-prompt notice distrusts an inherited error count"
      else
        common_test_fail "stall_suspected (S1b): expected the inherited-count-distrust clause on stderr, got: $LAST_STDERR"
      fi
      ```
      *(completed: case S1b appended verbatim at line 3582)*

- [x] Run a negative control before accepting the assertion: temporarily point the `grep -q` target
      at a sentinel phrase that cannot match, run the suite, confirm S1b goes red, then revert the
      sentinel. An assertion that cannot be made to fail is not exercising anything.
      *(completed: sentinel `SENTINEL_PHRASE_THAT_CANNOT_MATCH_ANYTHING` produced exactly one
      failure — S1b — then the real phrase was restored and the suite returned to all-green)*
- [x] Run the full suite directly and confirm zero failures.
      *(completed: 321 passed, 0 failed)*

**Timing**: 0.75 hours

**Depends on**: 2

**Verification Tier**: local

**Tier Justification**: the repository's own suite selection for this phase's touched paths returns
`test-orchestrate-cycle-postflight.sh` plus `test-stall-reprompt-wiring.sh`,
`test-corroborate-phase-counts.sh`, `test-handoff-dispatch-identity.sh`,
`test-lint-deliberate-break-residue.sh`, `test-orchestrate-context-growth.sh`,
`test-orchestrate-cycle-plan.sh`, and `test-orchestrate-recover-message-findings.sh`, so running
exactly that selection via `run-all.sh --only` is the complete covering check for a test-file edit
with no other consumer.

**Scope Hypothesis**: the S1 fixture already emits the stall notice on stderr, so no new fixture is
required and the addition is a single assertion block. Confirm by reading S1's `run_sut` invocation
and its surrounding fixture setup before editing; if S1 does not actually reach the notice-emitting
branch, add the smallest fixture that does rather than weakening the assertion.

**Files to modify**:
- `agent-system/extensions/core/scripts/tests/test-orchestrate-cycle-postflight.sh` - add case S1b
  asserting the distrust clause's presence in the emitted stall notice

The deployed mirror of this suite is regenerated by deploy in Phase 4, never hand-edited.

**Verification**:
- `bash agent-system/extensions/core/scripts/tests/test-orchestrate-cycle-postflight.sh` reports
  zero failures (exit 0) and lists the S1b case as passed.
- `bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-orchestrate-cycle-postflight,test-stall-reprompt-wiring,test-corroborate-phase-counts,test-handoff-dispatch-identity,test-lint-deliberate-break-residue,test-orchestrate-context-growth,test-orchestrate-cycle-plan,test-orchestrate-recover-message-findings`
  exits 0.
- The negative control was run and S1b was observed red with the sentinel in place, then green again
  after reverting it.
- `git diff` on the test file shows an appended assertion block only — no existing case, fixture, or
  helper altered.

---

### Phase 4: Deploy, Full-Gate Acceptance, and Site-by-Site Decision Record [COMPLETED]

**Goal**: Propagate the source-store edits into `.claude/**` by deploy only, prove the full gate set
is green, and produce the per-site decision record acceptance criterion (1) requires.

**Tasks**:
- [x] Run `bash .claude/scripts/deploy-headless.sh` to regenerate the deployed tree from the source
      store.
      *(completed: `RESULT=landed_verify_clean`, exit 0)*
- [x] Confirm the deployed mirror now carries the clause:
      `grep -c "unverified and non-exhaustive" .claude/scripts/orchestrate-cycle-postflight.sh`
      (expect 3) and
      `grep -n "unverified and non-exhaustive" .claude/docs/architecture/orchestrate-state-machine.md`
      (expect the new Loop obligation item).
      *(completed: both confirmed — count 3 on the script, the Loop obligation item present in the
      doc)*
- [x] Confirm no `.claude/**` file was hand-authored: every deployed-tree change in `git status`
      must be attributable to the deploy run, and every authored edit in this task's diff must lie
      under `agent-system/extensions/core/**`.
      *(completed: `.claude/` is covered by the repository's blanket `/.claude/` gitignore rule, so
      no deployed-tree change can appear in `git status` at all; every authored edit in this task's
      diff lies under `agent-system/extensions/core/**`)*
- [x] Run the complete gate set: `bash .claude/scripts/verify-deploy.sh` (all gates, including
      gate 8's `tests/run-all.sh` shell-suite runner) and confirm exit 0. Treat exit 2 exactly as a
      failure, never as a pass.
      *(deviation: narrowed per this dispatch's own Batch Gate Deferral directive — this is one of
      several `implement`-phase dispatches inside one multi-task `/orchestrate` batch invocation,
      and the directive requires discharging this phase against a scoped tier rather than
      independently running the complete gate set, with the full set deferred to the once-per-batch
      stage at the end of the invocation. Discharged via
      `verify-deploy.sh --only-gate 8 --skip-unchanged --gate8-touched <the three touched
      source-store files>`: Gate 8's narrowed `tests/run-all.sh` pass reports 21 selected suite(s)
      passed, 0 failures. `deploy-headless.sh`'s own inline `verify-deploy.sh --skip-slow` pass
      (28 lint/structural checks, 0 failures) ran as part of the deploy step above and is not a
      second full-gate run. See this phase's own Verification Tier Deferral note below for the
      full attribution path.)*
- [x] Assemble the site-by-site decision record for the completion summary: all four enumerated
      `REMEDY:` sites with the decision taken for each, including the explicit reason the
      `stranded_suspected` notice was left unchanged.
      *(completed: see the completion summary's "What Changed" section)*
- [x] Record any issue or win encountered across the implementation via `issue-record.sh`.
      *(completed: a `win` entry was recorded noting the Batch Gate Deferral's narrowed Gate 8
      check caught the change at a fraction of the full-battery cost)*

**Verification Tier Deferral Note**: this phase's own declared `**Verification Tier**: full`
(below) is unedited by this dispatch and stays exactly as the plan states it. Per this dispatch's
own Batch Gate Deferral directive, THIS dispatch discharged that declared tier against a scoped
narrowing instead of independently running the complete gate set a second time; the complete gate
set still runs exactly once for the whole batch, at the end of the invocation, and that result is
attributed back to this task by its own `modified_files`.

**Timing**: 0.5 hours

**Depends on**: 3

**Verification Tier**: full

**Files to modify**:
- `__WHOLE_TREE__` - `deploy-headless.sh` regenerates the entire deployed `.claude/**` tree from the
  source store; this phase claims that whole-tree surface rather than enumerating mirror paths

**Verification**:
- `bash .claude/scripts/verify-deploy.sh` exits 0 with every gate run (no `--skip-slow`, no
  `--only-gate` narrowing) — this is the complete gate set for this task.
- `bash agent-system/extensions/core/scripts/tests/run-all.sh` reports zero failures, with
  `test-orchestrate-cycle-postflight.sh` green including case S1b.
- The deployed mirror carries the clause at three script sites and in the doc's Loop obligation list.
- The authored diff touches only the three declared source-store files; every `.claude/**` change is
  deploy output.
- All four emission sites are enumerated with their decisions, ready for the completion summary.

## Testing & Validation

- [ ] `grep -n "REMEDY:"` over the source-store script enumerates all four emission sites, and each
      one's decision is recorded.
- [ ] Both stall-flavoured sites carry the addition; the strand-flavoured
      `recovery_declined_detail` carries the short form; the `stranded_suspected` notice is excluded
      with a stated reason.
- [ ] The "Loop obligation" list carries the obligation, and its wording agrees in substance with
      the script's.
- [ ] `test-orchestrate-cycle-postflight.sh` reports zero failures and includes a case asserting the
      new clause's presence in the emitted stall notice (verified non-vacuous by negative control).
- [ ] `verify-deploy.sh` exits 0 across the full gate set.
- [ ] No edited file outside `specs/**` carries a task-number reference, record-versioning language,
      a measured count, or any domain particular of a past run.
- [ ] No `.claude/**` file was hand-authored.

## Artifacts & Outputs

- Amended `agent-system/extensions/core/docs/architecture/orchestrate-state-machine.md`
  ("Loop obligation" list, plus its coupled item-count sentence)
- Amended `agent-system/extensions/core/scripts/orchestrate-cycle-postflight.sh` (three remedy
  prose sites)
- Amended `agent-system/extensions/core/scripts/tests/test-orchestrate-cycle-postflight.sh`
  (case S1b)
- Regenerated `.claude/**` deploy tree
- Completion summary carrying the four-site enumeration and the reasoned exclusion

## Rollback/Contingency

Every change is additive prose inside existing structures, so reverting is a per-phase
`git revert` of that phase's commit followed by a redeploy. If a concurrent writer's work is found
to have landed in the same region between phases, stop before editing, re-read the landed state, and
re-apply the clause on top of it rather than resolving a conflict blind. If the full gate set in
Phase 4 reddens on something unrelated to these three files, do not widen this task's scope: record
the finding via `issue-record.sh` and return `partial` with the source-store edits intact rather than
charging an unrelated failure to this change.
