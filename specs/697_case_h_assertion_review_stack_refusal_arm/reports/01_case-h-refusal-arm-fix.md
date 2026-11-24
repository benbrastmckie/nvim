# Research Report: Task #697

**Task**: 697 - Case H assertion, review-stack refusal arm
**Started**: 2026-11-24T04:31Z
**Completed**: 2026-11-24T05:10Z
**Effort**: small
**Dependencies**: None (665 depends on this one; this one does not depend on 665)
**Sources/Inputs**: Codebase (source-store scripts and test suites), `specs/decisions/*.md`, `specs/state.json`
**Artifacts**: - this report
**Standards**: report-format.md, subagent-return.md

## Executive Summary
- Remedy **(a)** is correct and should be implemented: retarget Case H's third assertion to
  assert `/please push <branch>` IS printed and `/merge` is NOT, matching the refusal arm that
  Case H's sandbox (which never installs `review-stack-prepare.sh`) actually exercises.
- Remedy (b) would additionally be throwaway: the accepted decision record
  `specs/decisions/slice-command-one-path-to-review.md` already rules that
  `review-stack-prepare.sh` and its suite are to be deleted, and that
  `milestone-review-handoff.sh` is to stop calling it (printing `/slice` instead). Building a
  success-arm fixture for `review-stack-prepare.sh` in this suite now would be test investment
  in a mechanism already slated for removal.
- The adjacent assertion (`.roadmap_milestones[0].review.state == "prepared"` and
  `.review.ref == refs/heads/<branch>`) is **still correct today** and should be left alone. The
  decision record that would retire the `review.ref` write (task 692's narrowing, noted as a
  pending `roadmap_annotation` on the now-completed task 692) has not been dispatched as a task
  yet — only the ruling itself has landed. The live code still performs that write
  unconditionally (both arms), so the assertion matches current behavior.

## Context & Scope

Task 692 (`handoff_prints_review_stack`, now `status: "completed"`) wired
`scripts/milestone-review-handoff.sh` to call `review-stack-prepare.sh cut --milestone <id>`
then `show`, non-fatally, with two arms: success prints/writes the real per-PR stack; refusal
prints the refusal reason plus `/please push <branch>` alone, deliberately suppressing `/merge`
(which cannot work from a bare refusal — it acts on the checked-out branch, refuses on
main/master, and hardcodes remote `origin`/target `main`). Task 692's own completion summary
names the resulting break in `test-orchestrate-conclusion-roadmap.sh` Case H as "the predicted,
out-of-scope breakage, recorded as an owed follow-up" — this task (697) is that follow-up.

This research verified the predicted breakage directly against the live files (not re-derived
from scratch, per the dispatch's framing) and additionally checked whether a second, independent
change — the `/slice` ruling that landed afterward in task 695 — invalidates the adjacent
`review.state`/`review.ref` assertion before this record touches the file.

## Findings

### Codebase Patterns

**Confirmed failure mechanics** (`agent-system/extensions/core/scripts/milestone-review-handoff.sh`):
- On refusal (missing/non-executable `review-stack-prepare.sh`, or a refusing `cut`/`show`), the
  script prints `rsp_reason_line`, then literally `/please push ${integration_branch}` on its
  own line, and explicitly does **not** print any `/merge` line (lines ~290–300 of the live
  file). This is a deliberate, documented suppression (script header, "WHAT IT DOES, PER
  MILESTONE" step 6).
- `test-orchestrate-conclusion-roadmap.sh`'s `build_sandbox()` (line 106) stages a fixed script
  set for the scratch `.claude/scripts/` tree; `review-stack-prepare.sh` does not appear
  anywhere in that file (confirmed by grep) — Case H's sandbox never installs it, so `cut`
  refuses with `script_missing` and the refusal arm is what runs. The dispatch's claim that "the
  sandbox does not install `review-stack-prepare.sh`" is verified, not assumed.
- Case H's third assertion block (`test-orchestrate-conclusion-roadmap.sh:512-516`) requires
  both `/please push ${caseH_branch}$` AND `^  /merge` in `$LAST_STDERR`. The second conjunct is
  structurally unreachable given the refusal arm the fixture exercises — confirmed, not
  re-derived.

**Reusable success fixture already exists** (`test-milestone-review-handoff.sh:113-129`,
`make_success_fixture_repo()`): wraps the base fixture with a declared `review_base` in
`.claude-extensions.json` and a `file://` remote whose path embeds `github.com/...`, letting
`review-stack-prepare.sh`'s resolver chain (`review_base`/remote/platform) succeed. This is the
borrowable shape option (b) would need; it is not reinvention work, but it is still strictly
more fixture machinery (a review-base declaration plus a GitHub-shaped bare remote) than option
(a) requires.

**The `review.ref` write is unconditional in the live code**, independent of which arm
(success/refusal) runs:
```
bash "$STATE_WRITE" \
  '(.roadmap_milestones[] | select(.id == $mid)).review = {"state": "prepared", "ref": $ref, "updated": $today}' \
  ...
```
This runs once per milestone transitioning `none -> prepared`, before the `review-stack-prepare.sh`
cut/show call. Case H's adjacent assertion (state.json's `review.state`/`review.ref`) is
testing exactly this write and is unaffected by which arm the stack-cut call takes.

### Decision-Record Findings (the adjacent-assertion check)

`specs/decisions/slice-command-one-path-to-review.md` (accepted, from task 695, now
`status: "completed"`) rules, among other things:
- `review-stack-prepare.sh` and its suite are to be **deleted** (ruling line 2; evidence table
  row for "Builder A").
- `milestone-review-handoff.sh` (row 3 of its mechanism table, and its "Narrow the handoff"
  phase) is **"Kept, narrowed"**: it keeps the once-per-milestone detection and the drafted
  summary, prints one line (`/slice`) with no push or merge line, and **stops writing
  `review.ref`**; `review.state` becomes "its own fired-once marker" with no slice meaning.
- The verdict row for `handoff_prints_review_stack` (692) is "**Survives revised**": task 692's
  already-landed wiring is explicitly superseded by this narrowing, which is a *separate,
  not-yet-dispatched* unit of work.

Cross-checked against `specs/state.json`: task 692 is `status: "completed"` and carries
`"roadmap_annotation": "plan predates the /slice ruling: revise before dispatch, to print /slice
and drop the review.ref write"`. This is a forward-looking annotation on a completed task, not a
dispatched or in-flight task — no task number currently owns implementing the narrowing. The
live file content (read directly, not inferred) confirms the narrowing has not happened: the
`review.ref`/`review.state` write and the `/please`-alone refusal printing are both still
present exactly as task 692 left them.

**Conclusion**: the adjacent assertion is still correct against the live code today. It will
become wrong once a future task implements the narrowing the `/slice` ruling calls for — at
which point that future task (not 697) owns revising this same assertion a second time, along
with the Case H MILESTONE-READY stderr-shape assertions and the `/please`-alone print this task
is about to retarget.

### External Resources

None consulted; this is a pure in-repo regression/decision-record cross-check with no external
dependency.

## Recommendations

1. **Implement remedy (a)**: in `test-orchestrate-conclusion-roadmap.sh`'s Case H third
   assertion block (lines 512-516), replace the `/merge`-conjunct check with a refusal-arm
   check: assert `/please push ${caseH_branch}$` IS present in `$LAST_STDERR` AND that no line
   matching `^  /merge` (or any `/merge` invocation shape) is present. Keep the existing
   `/please` regex; add a negative assertion for `/merge`, mirroring
   `test-milestone-review-handoff.sh`'s own refusal-arm Case 3 assertion shape (its negative
   `/merge` check pairs with the same positive `/please push` check already proven there).
2. **Leave the adjacent `review.state`/`review.ref` assertion (lines 522-526) untouched.** State
   explicitly in the plan (per the dispatch's instruction) that it was checked against the live
   file and decision records and found still correct, with the reason given above, so a future
   reader does not re-litigate it.
3. Do not implement remedy (b) now: it would build fixture investment (a declared `review_base`
   plus a GitHub-shaped remote) around `review-stack-prepare.sh`'s success arm, which the
   accepted `/slice` ruling has already scheduled for deletion. Choosing (a) is not merely
   smaller — it is the only one of the two that is not already obsolete by an accepted decision.
4. After the fix, run both suites to verify: `test-orchestrate-conclusion-roadmap.sh` green in
   full (Case H passing on the refusal-arm shape) and `test-milestone-review-handoff.sh`
   unregressed, then redeploy via `deploy-headless.sh` with the bounded-wait idiom
   (`timeout 540`, Bash tool timeout 600000) and confirm a clean verify, per the dispatch's
   VERIFY BY section.

## Decisions
- Remedy chosen: **(a)**, per the dispatch's own recommendation, now corroborated by the
  `/slice` ruling's disposition of `review-stack-prepare.sh` (scheduled deletion) — reinforcing
  rather than merely permitting the smaller fix.
- The adjacent `review.state`/`review.ref` assertion is ruled **still correct** and is left
  unmodified by this task.

## Risks & Mitigations
- **Risk**: a future task implementing the `/slice`-ruling's narrowing of
  `milestone-review-handoff.sh` will break both the retargeted Case H third assertion (no more
  `/please`/`/merge` lines at all — a bare `/slice` line) and the adjacent `review.ref`
  assertion (write removed) a second time. **Mitigation**: none owed by this task — the ruling
  record itself already names this as a successor's job ("Narrow the handoff", mechanism row 3,
  "Survives revised"). This report flags it so the eventual successor does not have to
  re-discover it.
- **Risk**: shared territory with task 665 (`previous_work_section_in_generated_roadmap`), which
  also declares `test-orchestrate-conclusion-roadmap.sh` in its `file_scope` and depends on this
  task. No mitigation needed beyond the existing dependency edge — this task runs first, as
  declared.

## Context Extension Recommendations
- none

## Appendix
- Files read: `agent-system/extensions/core/scripts/milestone-review-handoff.sh`,
  `agent-system/extensions/core/scripts/tests/test-orchestrate-conclusion-roadmap.sh` (Case H
  block, `build_sandbox()`), `agent-system/extensions/core/scripts/tests/test-milestone-review-handoff.sh`
  (`make_success_fixture_repo()`, Case 3/3b), `agent-system/extensions/core/scripts/review-stack-prepare.sh`
  (header only), `specs/decisions/slice-command-one-path-to-review.md` (ruling, evidence table,
  Assertions-amended table), `specs/decisions/review-slices-are-declared-tasks.md` (amendment
  note), `specs/state.json` (projects 692, 695, 665, 697).
- Searches: `grep -n "review-stack-prepare" test-orchestrate-conclusion-roadmap.sh` (no hits —
  confirms the sandbox omission); `grep -n "milestone-review-handoff" slice-command-one-path-to-review.md`.
