# Implementation Plan: Task #697

- **Task**: 697 - Case H assertion, review-stack refusal arm
- **Status**: [IMPLEMENTING]
- **Effort**: 1.25 hours
- **Dependencies**: None (task 665 carries the dependency edge onto this one; this one depends on nothing)
- **Research Inputs**: specs/697_case_h_assertion_review_stack_refusal_arm/reports/01_case-h-refusal-arm-fix.md
- **Artifacts**: plans/01_case-h-refusal-arm-fix.md (this file)
- **Standards**:
  - .claude/context/formats/plan-format.md
  - .claude/context/standards/status-markers.md
  - .claude/rules/artifact-formats.md
  - .claude/rules/state-management.md
  - .claude/rules/source-store-deploy-boundary.md
- **Type**: meta
- **Lean Intent**: false

## Overview

`scripts/tests/test-orchestrate-conclusion-roadmap.sh` Case H's third assertion requires both a
`/please push <branch>` line and a `^  /merge` line on the system-under-test's stderr. The
review-stack wiring that landed in `scripts/milestone-review-handoff.sh` made the second conjunct
structurally unreachable from the arm Case H's sandbox actually exercises: the sandbox never
installs `review-stack-prepare.sh`, so `cut` refuses `script_missing` and the refusal arm runs,
which prints the refusal reason plus `/please push <branch>` alone and deliberately suppresses
`/merge`. This plan implements remedy **(a)**: retarget the assertion to the refusal-arm shape —
assert `/please push <branch>` IS printed and `/merge` is NOT — converting the case into a
positive regression guard for the `/merge` suppression. Done means both named suites green and a
clean redeploy verify.

### Research Integration

The research report corroborates remedy (a) and adds one finding that upgrades it from
"recommended because smaller" to "the only non-obsolete option": the accepted decision record
`specs/decisions/slice-command-one-path-to-review.md` already rules that
`review-stack-prepare.sh` and its suite are to be **deleted**, and that
`milestone-review-handoff.sh` is to be kept-but-narrowed (printing one `/slice` line, with no
push or merge line, and no longer writing `review.ref`). Remedy (b) would therefore build new
fixture machinery — a declared `review_base` plus a GitHub-shaped bare remote, borrowable from
`test-milestone-review-handoff.sh`'s `make_success_fixture_repo()` — around a success arm already
scheduled for removal. The report also establishes that the narrowing has **not** been dispatched
as a task: it exists only as a `roadmap_annotation` on the already-completed task that wired the
current behavior.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No roadmap context was provided to this dispatch (`roadmap_path` absent, `roadmap_flag` absent),
so no roadmap-review or roadmap-regenerate phase is included and no roadmap item is claimed here.

### Premise Re-Validation (Carried-Figure Discipline)

Every flagged figure in the dispatch description was checked against live state in this dispatch,
not carried on the report's word. Results, including the ones that only confirm the description:

| Description claim | Check run | Result |
|---|---|---|
| Source store is the edit target; resolve `source_dir` from `.claude-extensions.json` | `jq -r '.extensions.core.source_dir' .claude-extensions.json` | **Confirmed.** Resolves to `/home/benjamin/.config/nvim/agent-system/extensions/core`; the three relevant files exist under it. |
| "THE SUITE IS RED RIGHT NOW" | Full run of `test-orchestrate-conclusion-roadmap.sh` | **Confirmed, exactly one red.** 34 passed, 1 failed, exit 1. The single failure is `Case H: expected literal /please and /merge lines`. |
| The failing block is Case H's third assertion, as quoted | `grep -n "/merge"` over the file | **Confirmed verbatim** at line 512, with its pass/fail messages at 513/515 and the case header comment at 486 — 4 occurrences in total, all inside Case H. |
| "The first conjunct still holds. The second cannot." | Captured stderr from the failing run | **Confirmed.** stderr contains `  /please push master` (matching the unanchored `/please push ${caseH_branch}$` regex) and the `REFUSED: review-stack-prepare.sh: script_missing:` reason line, with **no** `/merge` line anywhere. |
| "Case H's sandbox does not install review-stack-prepare.sh" | `grep -n "review-stack-prepare"` over the suite file | **Confirmed.** Zero hits, and the live run's refusal reason is literally `script_missing`. |
| `/merge` suppression on the refusal arm is deliberate | Read of `milestone-review-handoff.sh` header and both output arms | **Confirmed.** The script header states it twice, and the refusal arm (around lines 358-360) emits the reason line, `To push, run:`, and `  /please push ${integration_branch}` with no `/merge`. |
| `test-milestone-review-handoff.sh` must not regress | Full baseline run of that suite | **Confirmed green now**: 19 passed, 0 failed, exit 0. This is the pre-change baseline the final phase compares against. |

### Adjacent-Assertion Ruling (the dispatch's CHECK, DO NOT ASSUME item)

**The adjacent assertion is still correct. It is left untouched by this plan.** This was
established before anything was planned for the file, by two independent means:

1. **Empirically.** In the live red run above, `Case H: state.json's review.state is 'prepared'
   with review.ref set` is among the 34 **passing** assertions. It is not a second latent red
   hiding behind the first.
2. **Against the decision records.** `specs/decisions/slice-command-one-path-to-review.md` does
   rule that `milestone-review-handoff.sh` stops writing `review.ref` and that `review.state`
   becomes a bare fired-once marker — but that ruling has not been implemented. The live script
   still performs the `review = {"state": "prepared", "ref": $ref, "updated": $today}` state
   write unconditionally, before the stack-cut call and independent of which arm runs, so the
   assertion matches current behavior exactly. The narrowing is carried only as a
   forward-looking `roadmap_annotation` on the completed task that wired the present behavior; no
   task currently owns implementing it.

Consequently this record rules nothing on `review.ref` and makes no change there. When a future
record does implement the narrowing, that record owns revising this assertion — together with the
`/please`-alone print this plan is about to retarget, which the same ruling will supersede a
second time. That is named here so the successor does not re-derive it.

## Goals & Non-Goals

**Goals**:
- Make Case H's third assertion match the refusal arm its own sandbox exercises: `/please push
  <branch>` present, `/merge` absent.
- Turn that assertion into a positive regression guard for the `/merge` suppression, which is
  otherwise asserted only inside `test-milestone-review-handoff.sh`'s own suite.
- Bring `test-orchestrate-conclusion-roadmap.sh` to green in full without regressing
  `test-milestone-review-handoff.sh`, and land the change in the source store with a clean
  redeploy verify.

**Non-Goals**:
- Remedy (b). Not implemented, and deliberately so — see Decisions below.
- Any change to Case H's sandbox, its fixture, or `build_sandbox()`. `review-stack-prepare.sh`
  stays uninstalled there.
- Any change to `scripts/milestone-review-handoff.sh` itself. Its behavior is the specification
  this test is being corrected against, not a thing to adjust.
- Any change to the adjacent `review.state`/`review.ref` assertion, per the ruling above.
- Implementing the `/slice` ruling's narrowing of the handoff script. No task owns that yet, and
  this record does not claim it.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| A negative assertion (`! grep /merge`) passes for the wrong reason — e.g. it would also pass if the whole handoff stopped firing | M | M | Do not let the negative stand alone. It is one conjunct in a block whose other conjuncts positively assert the refusal arm ran: the `REFUSED: review-stack-prepare.sh:` reason line and the `/please push <branch>` line. A silent handoff would fail those. |
| A too-loose `/merge` regex matches prose mentioning `/merge` rather than an invocation line | L | L | Reuse the anchored shape already proven in `test-milestone-review-handoff.sh` Case 3 (`^  ?/merge( \|$)`), which matches an invocation line and not a sentence containing the word. |
| A future record implementing the `/slice` narrowing breaks this retargeted assertion again | M | M | Not owed here, and not silently left. Named explicitly in the ruling subsection above so the successor inherits the finding instead of re-discovering it. |
| Shared territory: task 665 also declares this same suite file in its `file_scope` | M | L | The declared order already resolves it — this record runs first and 665 carries the edge. Re-read the file immediately before editing; stage only this task's own hunks; never a directory or glob add. The file was verified clean (`git status --short` empty) at plan time. |
| Concurrent siblings (645, 639) editing the source store this same cycle | L | M | Their declared `file_scope` sets are disjoint from this one. An unexpected failure in a file outside this task's scope is treated as a possible sibling in-flight edit and reported, not absorbed as this task's regression. |

## Decisions

- **Remedy (a) is chosen; remedy (b) is rejected.** (a) retargets the assertion to the refusal-arm
  shape the sandbox actually exercises. It is the smaller change, leaves the sandbox untouched,
  and gains a regression guard for the `/merge` suppression. (b) is rejected not merely for size
  but because it is already obsolete: the accepted ruling in
  `specs/decisions/slice-command-one-path-to-review.md` schedules `review-stack-prepare.sh` and
  its suite for deletion, so a new success-arm fixture built around it would be investment in
  machinery with a deletion already ruled. Only one remedy is implemented.
- **The `/merge` negative is anchored, not bare.** The assertion reuses
  `test-milestone-review-handoff.sh` Case 3's proven `^  ?/merge( |$)` shape rather than a bare
  substring test, so a future prose mention of `/merge` in the handoff output does not fail the
  case spuriously.
- **The adjacent `review.state`/`review.ref` assertion is ruled still correct and left
  unmodified**, on both empirical and decision-record grounds (see the ruling subsection above).

## Implementation Phases

**Dependency Analysis**:

| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2 | 1 |

Phases within the same wave can execute in parallel.

### Phase 1: Retarget Case H's third assertion to the refusal-arm shape [COMPLETED]

**Goal**: Case H's third assertion asserts the refusal arm's real output — the refusal reason and
`/please push <branch>` present, `/merge` absent — and
`test-orchestrate-conclusion-roadmap.sh` runs green in full, with
`test-milestone-review-handoff.sh` still green.

**Tasks**:
- [x] Re-read `agent-system/extensions/core/scripts/tests/test-orchestrate-conclusion-roadmap.sh`
      immediately before editing (shared territory with task 665; a sibling may have touched it
      since plan time). *(completed: re-read; no sibling edit since plan time)*
- [x] Confirm the scope hypothesis below with `grep -n "/merge"` over the file. Expect 4
      occurrences, all inside Case H: the case header comment, the assertion condition, and its
      pass and fail messages. If the count or their locations differ, stop and reconcile against
      the live file before editing — the line numbers in this plan are a plan-time observation,
      not a guarantee. *(completed: exactly 4 occurrences at lines 486/512/513/515, all inside
      Case H, matching the plan's scope hypothesis)*
- [x] Replace the assertion condition so it asserts the refusal arm. Keep the existing positive
      `/please push ${caseH_branch}$` check unchanged (it already passes), add a positive check
      for the refusal reason line (`^REFUSED: review-stack-prepare\.sh: `), and replace the
      `grep -q "^  /merge"` conjunct with the negated, anchored form
      `! grep -qE "^  ?/merge( |$)"` — the shape already proven in
      `test-milestone-review-handoff.sh` Case 3. *(completed)*
- [x] Update the pass and fail messages so they describe what is now asserted (the refusal arm's
      `/please`-alone shape with `/merge` suppressed), not a `/please + /merge` pair. A message
      left describing the old pairing is a stale assertion label, not a cosmetic detail.
      *(completed)*
- [x] Update Case H's header comment block so its summary line names the refusal arm's output
      shape instead of "the literal /please + /merge commands on stderr", and note that the
      sandbox deliberately does not install `review-stack-prepare.sh`, which is what makes the
      refusal arm the arm under test. *(completed)*
- [x] Leave the adjacent `review.state`/`review.ref` assertion exactly as it is — it was checked
      and ruled still correct (see the ruling subsection above). Make no edit there.
      *(completed: left untouched, confirmed still passing)*
- [x] Run `bash agent-system/extensions/core/scripts/tests/test-orchestrate-conclusion-roadmap.sh`
      and confirm green in full, with Case H's retargeted assertion among the passes.
      *(completed: 35 passed, 0 failed)*
- [x] Run `bash agent-system/extensions/core/scripts/tests/test-milestone-review-handoff.sh` and
      confirm it still reports 19 passed, 0 failed — the baseline measured at plan time.
      *(completed: 19 passed, 0 failed, unregressed)*
- [x] Commit this phase's own hunks only, by explicit file list, never a directory or glob add.
      *(completed)*

**Timing**: 0.75 hours

**Depends on**: none

**Verification Tier**: local

**Tier Justification**: `bash agent-system/extensions/core/scripts/verify-touched.sh
agent-system/extensions/core/scripts/tests/test-orchestrate-conclusion-roadmap.sh` covers this
edit — `suite_selection_select` was run over this phase's whole `Files to modify` set at
authoring time and returned exactly `test-orchestrate-conclusion-roadmap.sh` and
`test-orchestrate-recap.sh`, the only suites a change confined to this one test file can affect.

**Scope Hypothesis**: Exactly 4 `/merge` occurrences require change, all inside Case H — at plan
time the case header comment (line 486), the assertion condition (512), and its pass (513) and
fail (515) messages; no occurrence lies outside Case H, and no other assertion block in the file
needs to change. Confirm at implementation time with `grep -n "/merge"` over the file before
editing, and reconcile against the live file if the count or locations differ.

**Files to modify**:
- `agent-system/extensions/core/scripts/tests/test-orchestrate-conclusion-roadmap.sh` - retarget
  Case H's third assertion to the refusal-arm shape; update its pass/fail messages and the case
  header comment to match.

**Verification**:
- `bash agent-system/extensions/core/scripts/tests/test-orchestrate-conclusion-roadmap.sh` exits
  0 with 0 failures (plan-time baseline: 34 passed, 1 failed; expected after: 35 passed, 0
  failed, subject to the assertion-count change this phase makes).
- Case H's retargeted third assertion appears among the passes, and the adjacent
  `Case H: state.json's review.state is 'prepared' with review.ref set` assertion still passes
  unmodified.
- `bash agent-system/extensions/core/scripts/tests/test-milestone-review-handoff.sh` still
  reports 19 passed, 0 failed, exit 0.
- `grep -n "/merge"` over the edited file shows no remaining occurrence that asserts or describes
  a `/merge` line as expected output on the refusal arm.

---

### Phase 2: Redeploy the tree and close out verification [COMPLETED]

**Goal**: The source-store change is mirrored into the deployed `.claude/` tree by the sanctioned
deploy engine, and the deploy's own verify reports clean.

**Tasks**:
- [x] Run the redeploy from the repository root using the bounded-wait idiom:
      `timeout 540 bash agent-system/extensions/core/scripts/deploy-headless.sh` with the Bash
      tool timeout set to 600000. Resolve to `bash .claude/scripts/deploy-headless.sh` instead if
      the source-store path does not exist in the repository the dispatch is running in.
      *(completed: ran, RESULT=landed_verify_clean, exit 0)*
- [x] Confirm the deploy reports a clean verify and exits 0. If it does not, fix forward from the
      reported failure — never discard uncommitted changes to reach a passing deploy.
      *(completed: 41 checks, 0 failures)*
- [x] Confirm the deployed copy of the suite carries the retargeted assertion, so the deploy
      actually mirrored this change rather than reporting clean on a stale tree. *(completed:
      `.claude/scripts/tests/test-orchestrate-conclusion-roadmap.sh` carries the
      `^REFUSED: review-stack-prepare\.sh: ` positive check and the old "/please + /merge" pass
      message is absent)*
- [x] Re-run `bash .claude/scripts/tests/test-orchestrate-conclusion-roadmap.sh` from the
      deployed tree and confirm green, closing the loop that the change survives deployment.
      *(completed: 35 passed, 0 failed; test-milestone-review-handoff.sh also re-run from the
      deployed tree: 19 passed, 0 failed)*
- [x] Discharge this phase's own in-dispatch gate obligation with the scoped touched-path check
      (`bash agent-system/extensions/core/scripts/verify-touched.sh` over this task's touched
      paths, or the `.claude/scripts/` form, whichever resolves), and record that the complete
      gate set is deferred to the orchestration close rather than independently run here.
      *(completed: ran via a bounded detached waiter; exited 1 with 0 NEW failures -- the sole
      failure was the pre-existing documented known-failure `test-gate-cache-equivalence.sh`
      (known-failures.txt line 33, load-sensitive, unrelated to this edit); this task's own
      targeted suites both passed in the same run. Logged via issue-record.sh. Full gate set
      deferred to the orchestration close, as directed by this dispatch's Batch Gate Deferral
      section.)*
- [x] Commit this phase's own hunks only, by explicit file list. The deployed `.claude/` tree is
      gitignored, so expect no `.claude/**` paths to stage; a non-failure skip for ignored
      members is expected, not a gap. *(completed)*

**Timing**: 0.5 hours

**Depends on**: 1

**Verification Tier**: full

**Files to modify**:
- `__WHOLE_TREE__` - this phase invokes whole-tree regeneration via the deploy script, which is
  an implicit scope claim over the entire deployed tree that no real declared path can express.
- `agent-system/extensions/core/scripts/tests/test-orchestrate-conclusion-roadmap.sh` - no
  further content change in this phase; declared because this phase's verification observes it
  through the deployed mirror.

**Verification**:
- The deploy exits 0 and reports a clean verify.
- The deployed `.claude/scripts/tests/test-orchestrate-conclusion-roadmap.sh` carries the
  retargeted assertion (not the pre-change `/merge` conjunct).
- `bash .claude/scripts/tests/test-orchestrate-conclusion-roadmap.sh` green in full from the
  deployed tree, and `bash .claude/scripts/tests/test-milestone-review-handoff.sh` still green.
- Under `/orchestrate`, this phase's own in-dispatch obligation is the scoped touched-path check
  above plus an explicit deferral of the complete gate set to the orchestration close; the full
  set is still owed once per invocation and is never forgiven. A standalone, non-orchestrated run
  of this phase instead runs the complete gate set directly
  (`bash agent-system/extensions/core/scripts/verify-deploy.sh`).

## Testing & Validation

- [ ] `test-orchestrate-conclusion-roadmap.sh` green in full, with Case H passing on the refusal
      arm — the arm its own sandbox exercises.
- [ ] Case H's assertion fails if the `/merge` suppression regresses (a `/merge` line reappearing
      on the refusal arm now fails this case, which is the guard this change buys).
- [ ] Case H's assertion also fails if the handoff stops firing altogether, because the positive
      refusal-reason and `/please push` conjuncts remain in the block.
- [ ] `test-milestone-review-handoff.sh` unregressed at 19 passed, 0 failed.
- [ ] The adjacent `review.state`/`review.ref` assertion still passes, unmodified.
- [ ] `deploy-headless.sh` reports a clean verify and exit 0.

## Artifacts & Outputs

- `agent-system/extensions/core/scripts/tests/test-orchestrate-conclusion-roadmap.sh` with Case
  H's third assertion retargeted to the refusal-arm shape, and its pass/fail messages and case
  header comment updated to match.
- A regenerated deployed `.claude/` tree carrying that change (gitignored; not a committed
  artifact).
- `specs/697_case_h_assertion_review_stack_refusal_arm/summaries/01_case-h-refusal-arm-fix-summary.md`
  at implementation close.

## Rollback/Contingency

The change is confined to assertion text in one test file, with no production-script edit, so
rollback is a revert of this task's own commits — the pre-change state is a known 34-pass/1-fail
red, not a broken tree. If the retargeted assertion proves unstable (for instance if a future
handoff change alters the refusal arm's output shape mid-flight), the contingency is to tighten
the positive conjuncts against the live output rather than to delete the case or weaken it to a
bare negative, which would silently stop guarding the `/merge` suppression. If the redeploy in
Phase 2 fails, fix forward from the reported failure; never discard uncommitted work to reach a
passing deploy.
