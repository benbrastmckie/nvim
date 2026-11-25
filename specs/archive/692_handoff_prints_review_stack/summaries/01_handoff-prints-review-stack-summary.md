# Implementation Summary: Task #692

- **Task**: 692 - Handoff prints the review stack
- **Status**: [COMPLETED]
- **Started**: 2026-11-24T01:49:31Z
- **Completed**: 2026-11-24T02:17:56Z
- **Effort**: ~1.75 hours
- **Dependencies**: None declared
- **Artifacts**: plans/01_handoff-prints-review-stack.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md,
  source-store-deploy-boundary.md, no-task-references-in-deliverables.md,
  no-record-versioning-in-deliverables.md

## Overview

`milestone-review-handoff.sh` ended by printing two hardcoded lines -- a `/please push`
request and a bare `/merge` -- even though `/merge` cannot work for a milestone review (it acts
on the checked-out branch, refuses on `main`/`master`, and hardcodes the remote `origin` and
target `main`). This work replaces that block with a call to the already-landed
`review-stack-prepare.sh cut --milestone <id>` followed by `show`: on success the real per-PR
review stack is printed and written into the milestone's summary file; on refusal (including a
missing script) the refusal reason is printed plus the `/please push <branch>` request alone,
with no `/merge` line anywhere. Both arms print a line stating that a push grant is bound to the
commit at HEAD when typed. The handoff script itself still contains no ref-writing, push-shaped,
or forge call.

## What Changed

- `agent-system/extensions/core/scripts/milestone-review-handoff.sh` -- added `rsp_script`
  pointing at the co-located `review-stack-prepare.sh`; added a non-fatal `cut`/`show` outcome
  computation inside the per-milestone loop (`rsp_ok`, `rsp_reason_line`, `rsp_show_output`);
  replaced the hardcoded `## Next Step` block (both in the written summary file and in the
  stderr output) with a success arm (`## Review Stack`, printing `show`'s output verbatim) and a
  refusal arm (the reason line, then `/please push <branch>` alone, no `/merge`); added the
  HEAD-binding grant line to both arms; updated the header comment to describe the current
  printed behaviour.
- `agent-system/extensions/core/scripts/tests/test-milestone-review-handoff.sh` -- `install_scripts`
  now copies `review-stack-prepare.sh` into its sandbox; Case 3 rewritten to the refusal-arm
  shape (asserting `REFUSED: review-stack-prepare.sh: review_base_undeclared:` specifically); a
  new `make_success_fixture_repo` builder (declaring `review_base=basepoint` and a `file://`
  remote whose path embeds `github.com/...`) backs a new Case 3b proving the cut-succeeds arm (2
  independent `PR N:` entries, two `/please push origin ...` lines, one `/merge --stack M1`
  line, the HEAD-binding line, in both the summary file and on stderr). Suite moved from 18 to
  19 passing cases.
- The deployed `.claude/` tree (gitignored; regenerated via `deploy-headless.sh`, not tracked by
  git).

## Decisions

- The cut/show outcome computation is written as plain loop-scoped shell variables (`rsp_ok`,
  `rsp_reason_line`, `rsp_show_output`), not `local`-declared, since the code runs at the top
  level of the script's per-milestone `while` loop rather than inside a function.
- `show`'s stderr is captured via a `mktemp` file, separately from its stdout, so its own "N
  grants needed" advisory NOTE is never surfaced while its `REFUSED:` line is still extractable
  on failure.
- "This system will not run either command on its own." was reworded to "...will not run any of
  these on its own." -- generic enough for the refusal arm's one command and the success arm's
  several, while preserving the "will not run" substring the suite asserts on.
- Verification for this phase's declared `full` tier was discharged via `verify-touched.sh`
  (both its no-arg batch-wide form, per this dispatch's Batch Gate Deferral directive, and a
  form scoped to this record's own 2 touched files) rather than an independent
  `verify-deploy.sh` run, per the multi-task `/orchestrate` batch this dispatch runs inside.

## Plan Deviations

- None (implementation followed plan). Phase 3's body gained a `#### Verification Notes`
  subsection documenting the two `verify-touched.sh` invocations in detail; this is elaboration
  of the plan's own verification step, not a deviation from it.

## Verification

- Build: N/A (bash scripts)
- Tests: `test-milestone-review-handoff.sh` 19 passed / 0 failed (up from an 18-case baseline).
  `lint-shellcheck.sh` and `lint-fixture-dependency-declaration.sh` both exit 0 for the edited
  files.
- Files verified: Yes -- `deploy-headless.sh` exited 0 (`RESULT=landed_verify_clean`), and the
  two deployed paths are byte-identical to the source store.
- `generate-context-line-counts.sh --check` exits 0 (608/608 exact).
- `check-task-references.sh` reports 0 unexempted occurrences under `agent-system/**`.
- `verify-touched.sh` scoped to this record's 2 touched files: 2 passed, 1 failed (1 NEW) -- the
  one failure is the predicted, out-of-scope `test-orchestrate-conclusion-roadmap.sh` Case H (see
  Follow-ups). The broader no-arg batch-wide form additionally surfaced an unrelated
  `test-gate-cache-equivalence.sh` 600s timeout, attributable to shared-tree contention from
  concurrent sibling dispatches this batch cycle, not to this record's work (confirmed absent
  from the file-scoped re-run).
- The complete gate set (`verify-deploy.sh` at full depth) is deferred to this multi-task
  `/orchestrate` batch's once-per-invocation close, per the dispatch's Batch Gate Deferral
  directive, and was not run independently in this dispatch.

## Impacts

- A milestone's review handoff now gives the operator a real, actionable stack of per-PR
  `/please push` requests (and a single trailing `/merge --stack <id>`) when
  `review-stack-prepare.sh` can cut one, instead of a `/merge` line that was never going to work
  for a milestone review.
- On any refusal (including environments that have not yet deployed `review-stack-prepare.sh`
  beside the handoff), the operator now sees the concrete reason instead of a misleading
  `/merge` suggestion.

## Follow-ups

- `agent-system/extensions/core/scripts/tests/test-orchestrate-conclusion-roadmap.sh` Case H
  (the assertion at line 512, `grep -q "/please push ${caseH_branch}\$" ... && grep -q "^
  /merge"`) now fails by design: its sandbox never installs `review-stack-prepare.sh`, so the
  handoff correctly takes the missing-script refusal arm there and prints no bare `/merge`,
  contradicting that still-unmodified assertion. Outside this record's declared `file_scope`
  (a concurrent sibling's territory this cycle); a future record should either install
  `review-stack-prepare.sh` in that suite's sandbox or rewrite Case H to the refusal-arm shape,
  matching what this record already did for `test-milestone-review-handoff.sh`'s own Case 3.
- The parent design record's Phase 5 prose updates to
  `agent-system/extensions/core/context/contracts/conclusion-stage.md` and
  `agent-system/extensions/core/context/standards/git-workflow-narrative.md` (describing the
  handoff's printed commands), plus the `index-entries.json` `line_count` reconciliation those
  doc edits would require, remain outside this record's `file_scope` and undone.

## References

- `specs/692_handoff_prints_review_stack/plans/01_handoff-prints-review-stack.md`
- `specs/692_handoff_prints_review_stack/reports/01_handoff-prints-review-stack.md`
- `specs/685_stack_pr_submission_from_integration_branch/plans/01_stack-pr-submission.md`
  (parent design record, Phase 5)
- `specs/decisions/review-slices-are-declared-tasks.md` (amendment noted in this task's
  description; this record's own deliverable is retained unchanged under that amendment)
