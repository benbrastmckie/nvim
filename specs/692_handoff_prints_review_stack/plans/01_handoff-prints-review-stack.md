# Implementation Plan: Task #692

- **Task**: 692 - Handoff prints the review stack
- **Status**: [NOT STARTED]
- **Effort**: 1.75 hours
- **Dependencies**: None declared
- **Research Inputs**: `specs/692_handoff_prints_review_stack/reports/01_handoff-prints-review-stack.md`
- **Artifacts**: plans/01_handoff-prints-review-stack.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md,
  source-store-deploy-boundary.md, no-task-references-in-deliverables.md,
  no-record-versioning-in-deliverables.md
- **Type**: meta
- **Lean Intent**: false

## Overview

`milestone-review-handoff.sh` today ends by printing two hardcoded lines --
`/please push <integration branch>` and a bare `/merge` -- both into
`specs/milestones/<id>-review-handoff.md` and onto stderr. The `/merge` cannot work for a
milestone review: `/merge` acts on the checked-out branch, refuses outright on `main`/`master`,
and hardcodes the remote `origin` and the target `main`. This plan replaces that block with a
call to the already-landed `review-stack-prepare.sh cut --milestone <id>`, followed by `show`,
printing the real per-PR stack on success and, on refusal, the refusal reason plus
`/please push <integration branch>` alone with no `/merge` line at all. One line stating that a
push grant is bound to `HEAD` at the time it is typed is printed on both arms.

The work is three phases: the script edit together with the refusal-arm test rewrite (the suite's
default fixtures exercise exactly the refusal arm, so this closes green); the success-arm fixture
and case; then the redeploy and scoped verification.

### Research Integration

Findings carried into the phases below, each re-verified against live state at authoring time:

- `cut --milestone <id>` defaults its own `stack_id` to `<id>` (`review-stack-prepare.sh:321`),
  so no `--stack-id` flag is needed; the handoff already holds the milestone id in `$mid`.
- `rsp_refuse()` calls `exit "$code"` directly and is never invoked inside a command-substitution
  subshell (`review-stack-prepare.sh:146-155`), so a caller can capture combined output with
  `"$(... 2>&1)"` and read `$?` safely. Refusals carry one line of the shape
  `REFUSED: review-stack-prepare.sh: <reason>: <message>` on stderr.
- `show --stack-id <id>` prints, per manifest entry in order,
  `PR N: branch=... base=... title=... body_path=...` then `  /please push <remote> <branch>`,
  then one trailing `/merge --stack <id>`; the "N grants needed" note goes to stderr only
  (`review-stack-prepare.sh:1073-1083`).
- `cut` prints its own `UNIT NN: tasks=... branch=... base=... end=...` lines to stdout
  (`rsp_cut_print`, `review-stack-prepare.sh:831-842`), redundant with `show`'s richer output.
  Capture `cut`'s output only to recover the exit code and the `REFUSED:` line; never surface it.
- "Script not found" is treated as a refusal, not an error: the handoff is advisory and exits 0
  always, and a test sandbox or older deploy may legitimately lack the script.
- The handoff's own `--dry-run` is NOT threaded into `cut`: `cut --dry-run` writes no manifest, so
  a following `show` would refuse `manifest_missing` (50) even though `cut` exited 0. The
  summary-file write is already unconditional with respect to `--dry-run` today
  (`milestone-review-handoff.sh:242-275`); only the `state-write.sh` call is gated. The new calls
  follow that existing precedent.
- `review-stack-prepare.sh`'s only dependencies are `lib/common.sh`,
  `lib/batch-admission-lib.sh`, `lib/task-lookup-lib.sh` and `deploy-root-guard.sh` -- all four
  already land in the handoff suite's sandbox (`cp -r ../lib/.` plus the explicit guard copy), so
  installing it needs exactly one new `cp` line.
- `test-review-stack-prepare.sh`'s `make_fixture_repo` (lines 49-75) is the reusable recipe for a
  fixture a `cut` can succeed against: a `file://` bare remote whose path embeds `github.com/...`
  (so the substring platform detector resolves `github` with no network), an early commit tagged
  `basepoint`, and `.claude-extensions.json` carrying `{"review_base": "basepoint"}`.

**Plan-time addition beyond the report**: `show` is dispatched only after
`rsp_resolve_integration_branch` / `rsp_resolve_review_base` / `rsp_resolve_remote` /
`rsp_detect_platform` have all run (`review-stack-prepare.sh:1182-1199`), so `show` carries its
own independent refusal surface (10-13, 20, 30-32) on top of `manifest_missing` (50). The
implementation therefore checks `show`'s exit status separately rather than treating a successful
`cut` as a guarantee.

**Premise re-validation** (Carried-Figure Discipline, three extracted lines, all confirmed
against live state at authoring time, none stale):

| Description line | Live check | Result |
|---|---|---|
| Source store is the edit target under `agent-system/extensions/core/**` | `jq -r '.extensions.core.source_dir' .claude-extensions.json` resolves to `/home/benjamin/.config/nvim/agent-system/extensions/core`; both file_scope paths exist there (299 and 345 lines) | Confirmed unchanged |
| `/merge` acts on the checked-out branch, refuses on `main`/`master`, hardcodes `origin` and target `main` | `commands/merge.md` lines 10, 30, 47, 51, 69, 126-145, 198-201 | Confirmed unchanged |
| The handoff contains no ref-writing git call | `test-milestone-review-handoff.sh` Case 10's two static checks both pass in a live run | Confirmed unchanged |

Baselines measured at authoring time, not carried from the report:
`test-milestone-review-handoff.sh` 18 passed / 0 failed; `test-review-stack-prepare.sh` 38 passed
/ 0 failed (matching the description's "38 passing cases" claim exactly).

### Prior Plan Reference

No prior plan for this record. The parent design record
`specs/685_stack_pr_submission_from_integration_branch/plans/01_stack-pr-submission.md` Phase 5
("Handoff prints the stack", lines 490-544) remains authoritative for the deliverable and is the
source of the task list below; its Phase 7 supplied the redeploy phase's shape, including the
`__WHOLE_TREE__` declaration convention. Its Phase 5 "Files to modify" list is wider than this
record's declared `file_scope` -- see Non-Goals.

### Roadmap Alignment

No `roadmap_path` was provided in this dispatch's delegation context, and `roadmap_flag` is not
set. No roadmap phases are added.

## Goals & Non-Goals

**Goals**:

- `milestone-review-handoff.sh` calls `review-stack-prepare.sh cut --milestone <id>` non-fatally
  after the per-task listing, then `show`.
- On success, `show`'s output is written into `specs/milestones/<id>-review-handoff.md` and
  printed as the final output, in place of the two lines printed today.
- On refusal (including a missing or non-executable script), the refusal reason is printed, the
  per-task listing is kept, `/please push <integration branch>` is printed alone, and no `/merge`
  line is printed anywhere.
- One printed line, on both arms, states that a grant is bound to `HEAD` at the time it is typed,
  so a commit by another session in between means typing the grant again.
- The handoff script itself still contains no ref-writing git call, no push-shaped call, and no
  forge invocation -- the existing static assertions stay green unmodified.
- `test-milestone-review-handoff.sh` is green with new cases covering the cut-succeeds arm, the
  cut-refuses arm, and the `HEAD`-binding line.
- The deployed `.claude/` tree carries the work.

**Non-Goals**:

- Editing `review-stack-prepare.sh` or its suite (concurrent sibling territory, declared
  `file_scope` of another record this same cycle).
- Editing `commands/merge.md` or `skills/skill-git-workflow/SKILL.md` (another concurrent
  sibling's declared `file_scope`).
- The parent plan's Phase 5 prose updates to
  `agent-system/extensions/core/context/contracts/conclusion-stage.md` and
  `agent-system/extensions/core/context/standards/git-workflow-narrative.md`, and the
  `index-entries.json` `line_count` reconciliation those doc edits would require. All three are
  outside this record's `file_scope`. (`index-entries.json` carries context-file entries only --
  zero entries under `scripts/` -- so this record's two script paths move no `line_count` value
  and couple to no generated surface.)
- Fixing `scripts/tests/test-orchestrate-conclusion-roadmap.sh` Case H, whose assertion this
  work will break. Outside `file_scope`; see Risks.
- Threading the handoff's `--dry-run` into `cut`, or inventing any new dry-run semantics.
- Any push, PR/MR creation, or grant minting.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| `test-orchestrate-conclusion-roadmap.sh` Case H (assertion near line 507) requires both `/please push <branch>` and a bare `^  /merge` on a fully-done milestone, in a sandbox that never installs `review-stack-prepare.sh`. Under the required behavior that sandbox takes the refusal arm, which must not print `/merge` -- so Case H goes red. | H | H (certain) | Out of `file_scope` by design. Already recorded as an issue by the research dispatch; named explicitly in Artifacts & Outputs as an owed follow-up so the next record picks it up rather than discovering a surprise failure. Phase 3 measures and reports the breakage rather than hiding it. |
| `cut`'s `UNIT NN: ...` stdout lines leak into the printed output if captured with `2>&1` into what is shown. | M | M | Capture `cut`'s combined output into a variable used only for the exit code and a `grep '^REFUSED:'` extraction; only `show`'s own stdout is ever surfaced. Phase 1 verification greps the output for `UNIT ` and asserts its absence. |
| A missing/non-executable `review-stack-prepare.sh` aborts the handoff instead of degrading. | H | M | Explicit `[ -x "$rsp_script" ]` guard before invoking; absence routes to the refusal arm with a named synthetic reason. The function must stay exit-0-always. |
| `show` refuses even though `cut` succeeded (its own resolver chain, or `manifest_missing`). | M | L | Check `show`'s exit status separately; a non-zero `show` falls into the same refusal arm, with `show`'s own `REFUSED:` line printed. |
| The success-arm fixture's task 932 has no landing proof, so `cut` may refuse `task_unattributable` (43) instead of falling back. | M | L | Phase 2 confirms the arm empirically before writing assertions; if the fallback does not fire, add a landing proof for 932 to the new fixture builder rather than weakening the case. |
| `make_fixture_repo` gains a `review_base` declaration and flips Case 3 from the refusal arm to the success arm, silently losing refusal coverage. | M | M | The success-arm fixture is a NEW wrapper builder layered on `make_fixture_repo "yes"`; the base builder is left declaring no `review_base`, keeping every existing case on the refusal arm. |
| On the success arm `cut` creates review branches, so a ref-stability assertion would fail. | L | M | Case 1's `refs_before = refs_after` assertion runs on a separate default-fixture repo that takes the refusal arm and stays green unmodified; the new success-arm case asserts no ref stability. The static no-ref-write assertion is about the handoff *file*, which gains no git call. |
| The handoff's `resolve_integration_branch` and `review-stack-prepare.sh`'s independent `rsp_resolve_integration_branch` could disagree on an edge case. | L | L | Not exercised by any fixture; Phase 2 notes the resolved values from the success-arm run so a disagreement would be visible rather than silent. |
| A sibling's in-flight edit to a file outside this record's `file_scope` is mistaken for a regression from this work. | M | M | Two siblings are dispatched this same cycle on this same tree. Re-read each target file immediately before editing; stage only this record's own two paths by explicit file list; treat an unexpected failure outside `file_scope` as possibly a sibling's in-flight edit and report it rather than fixing it. |

## Implementation Phases

**Dependency Analysis**:

| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2 | 1 |
| 3 | 3 | 1, 2 |

Phases within the same wave can execute in parallel.

### Phase 1: Wire `cut`/`show` and the refusal arm [NOT STARTED]

**Goal**: The handoff calls `cut` non-fatally and `show` on success, prints the stack or the
refusal reason with `/please push` alone and no `/merge`, prints the `HEAD`-binding line, and the
suite is green with its refusal-arm coverage rewritten to match.

**Tasks**:

- [ ] Re-read `scripts/milestone-review-handoff.sh` and
      `scripts/tests/test-milestone-review-handoff.sh` immediately before editing (concurrent
      siblings share this tree).
- [ ] In `scripts/milestone-review-handoff.sh`, add `rsp_script="${SCRIPT_DIR}/review-stack-prepare.sh"`
      beside the existing `STATE_WRITE="${SCRIPT_DIR}/state-write.sh"` definition (line 66),
      following the same co-located-script convention.
- [ ] Inside the per-milestone loop, after `task_lines` is built and before the summary file is
      written, compute the stack outcome into three locals (`rsp_ok`, `rsp_reason_line`,
      `rsp_show_output`):
      - `[ -x "$rsp_script" ]` false -> `rsp_ok=false`, synthetic reason line naming that
        `review-stack-prepare.sh` was not found beside the handoff.
      - otherwise run `cut --milestone "$mid"` capturing combined output for the exit code only;
        on non-zero, `rsp_ok=false` and `rsp_reason_line` is the captured `^REFUSED:` line (or a
        synthetic line naming the exit code when no `REFUSED:` line was emitted).
      - on zero, run `show --stack-id "$mid"` capturing stdout; a non-zero `show` also sets
        `rsp_ok=false` with `show`'s own reason line.
      Do not thread the handoff's `--dry-run` into either call. Never print `cut`'s own stdout.
- [ ] Replace the `## Next Step` block written into `$summary_path` (today lines 266-273) with
      two arms: on success a `## Review Stack` section carrying `$rsp_show_output` verbatim inside
      a fenced block; on refusal a `## Next Step` section carrying the reason line, then
      `/please push ${integration_branch}` alone inside a fenced block with no `/merge` line.
- [ ] Append, on both arms and in both the summary file and the stderr output, one line stating
      that a grant is bound to `HEAD` at the time it is typed, so a commit by another session in
      between means typing the grant again. (Mechanism confirmed in `lib/push-grant-lib.sh`: a
      grant's `HEAD_SHA` is fixed at mint time and must equal current `HEAD` to be consumed.)
- [ ] Mirror the same two arms in the stderr block, replacing the hardcoded
      `  /please push ${integration_branch}` / `  /merge` pair at lines 294-295. Keep the
      existing "This system will not run either command on its own." statement (rewording it only
      as far as its "either" no longer fits), since Case 3's `will not run` assertion depends on
      it.
- [ ] Update the script's header comment (lines 5, 9, 45) to describe the current printed
      behaviour: it prepares and prints the review stack, or the refusal reason plus the
      `/please push` request alone; it still never pushes, never opens a PR/MR and never mints a
      grant. State the current behaviour only -- no draft-history or supersession language
      (`rules/no-record-versioning-in-deliverables.md`), and no task-number reference
      (`rules/no-task-references-in-deliverables.md`).
- [ ] Rewrite Case 3 of `scripts/tests/test-milestone-review-handoff.sh` (today lines 189-199)
      from the `/please` + bare `/merge` pair to the refusal-arm shape: the default fixtures
      declare no `review_base`, so `cut` refuses `review_base_undeclared` there. Assert a
      `REFUSED: review-stack-prepare.sh: review_base_undeclared:` line, `/please push ${BRANCH}`
      present, the `will not run` statement present, the `HEAD`-binding line present, and no
      bare `/merge` line anywhere in the output. Note: this case's sandbox does not yet install
      `review-stack-prepare.sh` -- Phase 2 adds that `cp`, so until then this case exercises the
      missing-script arm; assert on whichever reason line the run actually produces and tighten
      it to `review_base_undeclared` once Phase 2's `cp` lands.
- [ ] Leave Case 10's two static checks untouched: `cut`/`show` invocations contain none of the
      literal strings they grep for.

**Timing**: 0.75 hours

**Depends on**: none

**Verification Tier**: local

**Tier Justification**: the covering check is
`bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-milestone-review-handoff.sh,test-orchestrate-conclusion-roadmap.sh,test-review-stack-prepare.sh`
-- the three suites `suite_selection_select` resolves for these touched paths; the first is the
only one asserting on this script's printed output, the third is unaffected (this phase edits
none of its inputs) and the second's Case H is the known out-of-scope expected-RED named in Risks
and measured in Phase 3.

**Scope Hypothesis**: the line citations above (`milestone-review-handoff.sh` 66, 242-275,
266-273, 294-295, and header lines 5, 9, 45; `test-milestone-review-handoff.sh` 189-199) were
measured against live state at authoring time, but two siblings are dispatched on this same tree
this cycle and earlier edits in this phase shift later lines. Confirm each anchor by re-reading
the file immediately before the edit and matching on surrounding text, never by line number
alone. The hypothesis that these two files are the whole edit set is likewise confirmed by the
suite passing, not by inspection.

**Files to modify**:

- `agent-system/extensions/core/scripts/milestone-review-handoff.sh` - `rsp_script` definition,
  the cut/show outcome computation, both arms of the summary-file write, both arms of the stderr
  block, the `HEAD`-binding line, and the header comment
- `agent-system/extensions/core/scripts/tests/test-milestone-review-handoff.sh` - Case 3 rewritten
  to the refusal-arm shape

**Verification**:

- `bash agent-system/extensions/core/scripts/tests/test-milestone-review-handoff.sh` exits 0 with
  no failed case.
- `bash agent-system/extensions/core/scripts/lint/lint-shellcheck.sh` exits 0 (sanctioned entry
  point; check the exit status, not a stdout diff).
- `grep -nE '^\s*echo "/merge"|^\s*echo "  /merge"' agent-system/extensions/core/scripts/milestone-review-handoff.sh`
  returns nothing: no bare `/merge` line is printed.
- The suite output contains no `UNIT ` line, confirming `cut`'s own stdout is not surfaced.
- Case 10's two static assertions still pass unmodified.

---

### Phase 2: The success arm, with its own fixture [NOT STARTED]

**Goal**: The suite installs `review-stack-prepare.sh` into its sandbox and proves the
cut-succeeds arm: `show`'s per-PR output lands in the summary file and on stderr, with the
`HEAD`-binding line, and the old two-line block is gone.

**Tasks**:

- [ ] Re-read `scripts/tests/test-milestone-review-handoff.sh` immediately before editing.
- [ ] Extend `install_scripts` (lines 38-47) with one `cp` of `../review-stack-prepare.sh` into
      `$d/.claude/scripts/`. Its four dependencies (`lib/common.sh`,
      `lib/batch-admission-lib.sh`, `lib/task-lookup-lib.sh`, `deploy-root-guard.sh`) are already
      installed by the existing wholesale `cp -r ../lib/.` and explicit guard copy -- confirm that
      claim by running the suite, and add only what a real failure proves missing. Do not
      introduce a `require_file` call: the suite is currently outside
      `lint-fixture-dependency-declaration.sh`'s population (no `require_file`, no `REQUIRED_*`
      array) and adding one would pull it in and demand a full declaration list.
- [ ] Add a new fixture builder wrapping `make_fixture_repo "yes"` (leave the base builder
      declaring no `review_base`, so every existing case keeps its refusal-arm behaviour):
      tag the seed commit `basepoint`, write
      `.claude-extensions.json` carrying `{"review_base": "basepoint"}` alongside whatever else
      that case needs, and add a `file://` remote whose path embeds `github.com/...`, following
      `test-review-stack-prepare.sh`'s `make_fixture_repo` (lines 49-75).
- [ ] Run the handoff against that fixture once and read the real output before writing
      assertions. Confirm `cut --milestone M1` exits 0 there. If it refuses
      `task_unattributable` (43) because task 932 has no landing proof, add a landing proof for
      932 to the new builder rather than weakening the case. Record the resolved
      `integration_branch` / `review_base` / `remote` / `platform` values the run reports, so a
      disagreement between the handoff's own branch resolver and
      `rsp_resolve_integration_branch` would be visible.
- [ ] Add the success-arm case asserting, against the observed output: a `PR N: branch=... base=...
      title=... body_path=...` line per manifest entry, a `  /please push <remote> <branch>` line
      per entry, one trailing `/merge --stack M1` line, the `HEAD`-binding line, and the absence
      of both the old bare `^  /merge$` line and the old standalone
      `/please push ${BRANCH}`-with-no-remote pair. Assert on the entry count the run actually
      produces, not an assumed one.
- [ ] Tighten Phase 1's rewritten Case 3 to assert the `review_base_undeclared` reason line
      specifically, now that the sandbox installs the script and the missing-script arm no longer
      fires there.
- [ ] Keep Case 1's `refs_before = refs_after` assertion on the default fixture only; add no ref
      assertion to the success-arm case, where `cut` legitimately creates review branches.

**Timing**: 0.75 hours

**Depends on**: 1

**Verification Tier**: local

**Tier Justification**: the covering check is
`bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-milestone-review-handoff.sh,test-review-stack-prepare.sh`
-- the two suites `suite_selection_select` resolves for this phase's one touched path; the first
is its only consumer and the check that proves both arms, and the second is named because the
selector returns it, unaffected since this phase edits none of its inputs.

**Scope Hypothesis**: the success-arm `cut` is expected to produce two independent review units
(tasks 931 and 932 share no path and carry no dependency edge in the fixture, so they form two
connected components, each a chain of length one), yielding two `PR N:` blocks; and the one new
`cp` line is expected to be the only sandbox-install change needed. Both are hypotheses, not
facts: confirm the unit count by reading the actual `show` output in the run step above before
writing the assertion, and confirm the dependency claim by running the suite rather than by
inspection.

**Files to modify**:

- `agent-system/extensions/core/scripts/tests/test-milestone-review-handoff.sh` -
  `install_scripts` gains the `review-stack-prepare.sh` copy; a new success-arm fixture builder
  and case; Case 3's reason-line assertion tightened

**Verification**:

- `bash agent-system/extensions/core/scripts/tests/test-milestone-review-handoff.sh` exits 0,
  with a case count strictly greater than the 18 measured at authoring time and no failed case.
- Both arms are proven in one run: the success-arm case's `PR 1:` assertion and the refusal-arm
  Case 3's `REFUSED: review-stack-prepare.sh: review_base_undeclared:` assertion both pass.
- `bash agent-system/extensions/core/scripts/lint/lint-shellcheck.sh` exits 0.
- `bash agent-system/extensions/core/scripts/lint/lint-fixture-dependency-declaration.sh` exits 0
  (the suite stays outside its population, or satisfies it if the implementer did add a
  declaration).

---

### Phase 3: Redeploy and scoped verification [NOT STARTED]

**Goal**: The deployed tree carries the work, the scoped touched-path check is green, and the
one known out-of-scope breakage is measured and reported rather than left to surprise a later
dispatch.

**Tasks**:

- [ ] Run `bash agent-system/extensions/core/scripts/deploy-headless.sh` and check its exit
      status. Confirm `.claude/scripts/milestone-review-handoff.sh` and
      `.claude/scripts/tests/test-milestone-review-handoff.sh` carry this record's content.
- [ ] Run `bash agent-system/extensions/core/scripts/generate-context-line-counts.sh --check` and
      check its exit status. This record edits no context file, so no `line_count` is expected to
      move; a RED here is a sibling's or a pre-existing condition, to be reported, not absorbed.
- [ ] Run `bash agent-system/extensions/core/scripts/verify-touched.sh` over this record's two
      paths and check its exit status.
- [ ] Measure `bash agent-system/extensions/core/scripts/tests/test-orchestrate-conclusion-roadmap.sh`
      and record the verdict. Case H is expected RED, for the reason given in Risks: its sandbox
      never installs `review-stack-prepare.sh`, so the handoff takes the missing-script refusal
      arm there and correctly prints no `/merge`, contradicting that case's assertion. Do NOT edit
      that file -- it is outside this record's `file_scope`. Report the exact failing assertion
      and its line in the handoff notes and summary as an owed follow-up.
- [ ] Run `bash .claude/scripts/check-task-references.sh` and confirm no new finding under
      `agent-system/**`.
- [ ] Under `/orchestrate`, defer the complete gate set to the orchestration close and record
      that deferral in this phase's notes. In a standalone, non-orchestrated run, invoke
      `bash .claude/scripts/verify-deploy.sh` directly instead.

**Timing**: 0.25 hours

**Depends on**: 1, 2

**Verification Tier**: full

**Files to modify**:

- `__WHOLE_TREE__` - this phase invokes whole-tree regeneration via `deploy-headless.sh`

**Verification**:

- `deploy-headless.sh` exits 0, and the two deployed paths match their source-store content.
- `generate-context-line-counts.sh --check` exits 0.
- Scoped check for this dispatch: `bash agent-system/extensions/core/scripts/verify-touched.sh
  agent-system/extensions/core/scripts/milestone-review-handoff.sh
  agent-system/extensions/core/scripts/tests/test-milestone-review-handoff.sh` reports green.
  Under `/orchestrate` the complete gate set is deferred to the orchestration close and that
  deferral is recorded in this phase's notes; in a standalone run
  `bash .claude/scripts/verify-deploy.sh` is run directly instead.
- `test-orchestrate-conclusion-roadmap.sh`'s verdict is recorded with its failing assertion named
  -- a RED Case H here is the expected, reported, out-of-scope breakage, not an unexplained
  failure.
- `bash .claude/scripts/check-task-references.sh` reports no new finding under `agent-system/**`.

## Testing & Validation

- [ ] `test-milestone-review-handoff.sh` exits 0, covering: the cut-succeeds arm (`show` output
      written into `specs/milestones/M1-review-handoff.md` and printed), the cut-refuses arm
      (reason printed, per-task listing kept, `/please push` alone, no `/merge`), and the
      `HEAD`-binding line's presence on both arms.
- [ ] The existing 18 cases' intent is preserved: only Case 3's expectation changes (to the
      refusal-arm shape), and Case 10's static no-push / no-ref-write assertions pass unmodified.
- [ ] `lint-shellcheck.sh` exits 0 for both edited files.
- [ ] `verify-touched.sh` over the two in-scope paths reports green.
- [ ] `generate-context-line-counts.sh --check` exits 0.
- [ ] `check-task-references.sh` reports no new finding under `agent-system/**`.
- [ ] `test-orchestrate-conclusion-roadmap.sh`'s verdict is measured and reported, with Case H's
      expected RED named explicitly as owed to a separate record.

## Artifacts & Outputs

- `agent-system/extensions/core/scripts/milestone-review-handoff.sh` - prints the review stack or
  the refusal reason plus `/please push` alone, with the `HEAD`-binding line; still no
  ref-writing, push-shaped or forge call
- `agent-system/extensions/core/scripts/tests/test-milestone-review-handoff.sh` - installs
  `review-stack-prepare.sh` in its sandbox; covers both arms and the `HEAD`-binding line
- The regenerated `.claude/` deploy tree
- Owed follow-ups, to be recorded in the handoff and summary rather than actioned here (each
  outside this record's `file_scope`):
  - `agent-system/extensions/core/scripts/tests/test-orchestrate-conclusion-roadmap.sh` Case H's
    assertion, which this work breaks by design
  - `agent-system/extensions/core/context/contracts/conclusion-stage.md` and
    `agent-system/extensions/core/context/standards/git-workflow-narrative.md` prose describing
    the handoff's printed commands, plus the `index-entries.json` `line_count` reconciliation
    those doc edits require

## Rollback/Contingency

Both in-scope edits are confined to two files whose only consumer is one suite, and the work
commits phase by phase, so reverting is a `git revert` of this record's own phase commits
followed by one `deploy-headless.sh` pass to bring the deployed tree back in line. No ref, no
remote and no grant is touched by any phase, so nothing outside the working tree needs undoing.

If `cut` cannot be made to succeed against any fixture within Phase 2's budget, the refusal arm
is the arm that matters for the defect this record addresses (the unusable `/merge` is suppressed
either way); close Phase 2 as `[COMPLETED WITH EXCLUSIONS]` with a `#### Reasoned Exclusions`
record naming the success-arm case and the exact refusal observed, rather than weakening an
assertion to pass.

Before any intentional rollback, snapshot first with
`bash .claude/scripts/git-snapshot.sh 692`. For an ordinary defensive checkpoint before risky
work, use `bash .claude/scripts/git-snapshot.sh 692 --no-revert` instead -- never the reverting
default, with two siblings live on this same tree.
