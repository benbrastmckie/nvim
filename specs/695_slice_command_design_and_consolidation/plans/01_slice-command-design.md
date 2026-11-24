# Implementation Plan: Task #695

- **Task**: 695 - Design the /slice command: one clean path from work branch to a stack of review pull requests
- **Status**: [NOT STARTED]
- **Effort**: 6.5 hours
- **Dependencies**: None
- **Research Inputs**: specs/695_slice_command_design_and_consolidation/reports/01_slice-command-design.md
- **Artifacts**: plans/01_slice-command-design.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

This task researches and rules; it builds nothing. The deliverable is one new decision record,
`specs/decisions/slice-command-one-path-to-review.md`, that rules the `/slice` design, names the
single surviving mechanism and every file to be deleted, carries a verdict row for each listed
open record, and amends `specs/decisions/review-slices-are-declared-tasks.md` where the research
overturns it. Every claim the record makes about an existing implementation is re-derived from
the live files with line numbers before it is written. Done means: a reader can tell from the new
record alone which mechanism survives, which files go, whether a review base exists, what the
size bar is, and what happens to each open record.

### Research Integration

The research report (`reports/01_slice-command-design.md`) is the primary input. Integrated
findings:

- F1: neither existing builder has production evidence; the task description's "22 opened, 18
  merged" attributes a repository's whole pull-request population to one tool.
- F2: three builders exist (the agent-system script, the sf1-engine script, a sapience-app
  script), all converging on one plumbing overlay primitive.
- F3/F4: the agent-system script is unwired and undeclared; the sf1-engine script is not
  promotable as code, but six of its design properties carry upstream.
- F5: two roles only (work ref, target); no third branch; target chosen at the prompt.
- F6: the size-bar method is portable, the numbers are not.
- F7/F8: seven paths move work toward review, two more than the task description lists.
- Decisions 1 to 10 and Recommendations R1 to R7 are the ruling's draft content.

The research names three gaps it did not close, and this plan closes each before the record
relies on it: the batch-isolation record was not read (the lowest-confidence verdict row); the
cslib `/pr` command was not read; `stack_cut.py` was read only by header and function list.

### Premise Re-Validation

Each flagged description line, checked against the research report and live state at plan time:

| Description claim | Result |
|---|---|
| Source store is the edit target; redeploy after editing | Confirmed as a standing rule (`source_dir` resolves to `agent-system/extensions/core` in this repository). **Not exercised by this plan**: the description's own deliverable section says "No implementation in this record", so no file under `agent-system/**` is edited and no redeploy is owed |
| "One ... has never opened a pull request. The other ... has opened 22, of which 18 merged" | **Contradicted** by the research report F1: the sf1-engine builder has opened zero. CARRIED-UNVERIFIED at plan time (forge read not repeated); Phase 1 re-runs it |
| A is 1,572 lines; suite at 61 passing cases; four subcommands | Line count confirmed live (`wc -l`: 1,572; suite file 1,136). The 61-case pass is CARRIED-UNVERIFIED from the research report's re-run; Phase 1 re-runs it |
| B is 2,165 lines; `pr-series.md` 418; `pr-release-pipeline.md` 518 | **B has moved**: live `wc -l` is 2,187, with an uncommitted modification. 418 and 518 confirmed. Every line-numbered citation of B in the research report is therefore stale-prone and is re-derived in Phase 1, not carried |
| RP3 ceiling figures and "median over 18 merged: 10 files, 1,258 added lines" | Superseded by the research report F6 live measurement (19 merged; median 1,173 added, 10 files). CARRIED-UNVERIFIED; Phase 1 re-measures |
| "Promote B upstream, delete A" hypothesis | Tested by the research report: half right (A deleted, B not promoted) |
| Repo-agnostic constraint on `agent-system/**` deliverables | Unchanged; binds the successors, not this plan, which writes only under `specs/**` |

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No roadmap context was supplied with this dispatch (`roadmap_path` absent, `roadmap_flag`
absent). `specs/ROADMAP.md` exists but was not consulted and carries no entry naming this task.

## Goals & Non-Goals

**Goals**:
- Write `specs/decisions/slice-command-one-path-to-review.md` ruling: the command surface; the
  basis implementation and the fate of the others; whether a review base exists; the size bar
  and its portability; the single survivor and the deletion list; the grant cost; a verdict row
  for every listed open record; the named successors.
- Re-derive every implementation claim from live files, with line numbers, at the commit read.
- Close the three reading gaps the research report left open before ruling on them.
- Amend `review-slices-are-declared-tasks.md` (S3, S4, S5 in part, S6, the retention list, "Why
  not abandon") by a dated amendment note, and correct the landing record's amendment pointer.
- Name at least one built or planned thing that is discarded.

**Non-Goals**:
- No edit under `agent-system/**` or `.claude/**`; no redeploy. Successors build.
- No change to any other task's record in `specs/state.json` or `specs/TODO.md`. Verdicts are
  stated in the record with an operator worklist; they are not executed here (see Decisions).
- No creation of successor task records.
- No edit to the commit-containment cluster (`scripts/git-commit-scoped.sh`,
  `context/standards/git-staging-scope.md`); dependencies on it are named as edges only.
- No edit to any file in sf1-engine or sapience-app; both are read-only evidence.
- No push, no pull-request creation, no forge write of any kind. Forge reads only.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| sf1-engine's builder keeps moving during implementation, so line citations go stale again | M | H | Phase 1 records the commit hash and dirty state it read, and cites lines against that; the record says so in its evidence header |
| The five-record "abandon" verdict rests on a record the research did not read | H | M | Phase 3 reads the batch-isolation record and both isolation-removal records first; if they do not support abandonment, the verdict becomes "stays held" with the reason, which the research names as the safe fallback |
| The design itself has zero production evidence | M | H | The record says so in its own risk section and requires the first successor to end with one real slice pushed and opened by the operator |
| Other dispatches are planning the handoff and merge-stack records concurrently against the old ruling | M | H | This plan edits neither record; the new record's verdict rows and worklist are what redirect them. Named in the handoff summary for the operator |
| Version-language habits leak into the record | L | M | `specs/**` is exempt from both deliverable rules; no mitigation needed beyond accuracy |
| A forge read fails or is rate-limited in Phase 1 | L | L | Mark the affected figure CARRIED-UNVERIFIED with the research report named as source; do not block the record |

## Decisions

1. **Verdicts are ruled, not executed.** The task description asks the record to "state" a
   disposition for each open record. Abandoning six records and rewriting three others is the
   operator's authorization to give, and two of the affected records are being planned by other
   dispatches in this session. The record therefore carries a disposition worklist naming the
   exact operator command per row; this plan changes no other task's state.
2. **A new record, plus an amendment note on the old one.** The research overturns four of
   seven rulings and the retention list of `review-slices-are-declared-tasks.md`. Rewriting that
   file in place would erase what was decided and why; a new record that supersedes the
   overturned parts, with a dated `**Amended by**` note at the top of the old one, keeps both
   readable. S1, S2 (outcome) and S7 stand and are said to stand.
3. **The 75th percentile, not the median, is the measured bar.** The research flags this as a
   preference. The record rules the 75th percentile and states the median as a rejected
   alternative on its merits (it would refuse half of what the reviewer has already merged).
4. **No source-store edit, so no `__WHOLE_TREE__` declaration and no redeploy phase.** The
   task's recorded `file_scope` anticipates four `agent-system/**` paths; this plan touches
   none of them. Those paths belong to the successors the record names.
5. **Evidence first, in the record itself.** Phase 1 writes the evidence section of the record
   before any ruling is written, so no ruling can cite a figure that was not re-derived.

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2 | 1 |
| 3 | 3 | 2 |
| 4 | 4 | 3 |
| 5 | 5 | 4 |

Phases within the same wave can execute in parallel. Phases 1 to 3 and 5 write the same file,
so the chain is strictly sequential.

### Phase 1: Re-derive the evidence and open the record [NOT STARTED]

**Goal**: Create the decision record with its header and a complete Evidence section in which
every claim about an existing implementation is re-derived from live files, with line numbers.

**Tasks**:
- [ ] Record the commits read: this repository's `HEAD`; sf1-engine's `HEAD` and whether
      `integration/tools/build-pr-slices.sh` is modified in its working tree; sapience-app's
      `HEAD`.
- [ ] Re-derive for `agent-system/extensions/core/scripts/review-stack-prepare.sh`: line count,
      the four subcommands, the line ranges of the resolver refusal (equal-name comparison),
      union-find, component building, topological sort, the overlay function, the moved-base
      `merge-tree`, and restack. Re-run `scripts/tests/test-review-stack-prepare.sh` from the
      source store and record the pass count.
- [ ] Re-derive callers: `grep -rl review-stack-prepare`, `grep -rl milestone-ref-land` and
      `grep -rl milestone-review-handoff` over the core extension; record each hit list.
- [ ] Re-derive for sf1-engine `build-pr-slices.sh` at the commit recorded: line count, the base
      literal, the ancestry refusal, the tree-composition and slice-build functions, the three
      structural checks, the dependency-scoped base logic, and the count of lines bound to that
      repository's diagnostics. Do not carry any line number from the research report.
- [ ] Read sapience-app `scripts/stack_cut.py` in full (the research read only its header and
      function list); confirm or correct "hunk-level cut and restack" and the overlay function's
      line range.
- [ ] Re-run the forge reads: `gh pr list --state all --limit 100 --json
      number,state,author,headRefName,baseRefName,additions,changedFiles,mergedBy` in sf1-engine
      and sapience-app; recompute merged count, author split, `pr/*` head count, and the median
      and 75th percentile of added lines and files per base. Re-run `git for-each-ref` for
      `refs/heads/{pr,review,milestone}` and `refs/remotes` in each repository checked.
- [ ] Re-derive for `commands/merge.md`, `hooks/please-grant.sh`, `hooks/guard-git-push.sh` and
      `scripts/lib/push-grant-lib.sh`: the checked-out-branch read, the default-branch refusal,
      the literal remote, the `--target` default, the minting prefixes, the `HEAD` match at
      consume time, and the expiry window default.
- [ ] Re-run both searches from the research report's F8 and record the union as the mechanism
      inventory, with the search that found each row.
- [ ] Confirm whether `review_base` is declared in each repository's `.claude-extensions.json`
      and whether `specs/.orchestration/reviews/` exists in any.
- [ ] Write the record's title, a "This record rules. It builds nothing." line, the decision
      date and session, and an `## Evidence` section holding the above as tables. Any figure
      that could not be re-derived is marked CARRIED-UNVERIFIED with its source named.
- [ ] State, in the evidence section, each place where the re-derivation differs from the
      research report or the task description.

**Timing**: 1.5 hours

**Depends on**: none

**Verification Tier**: prose

**Tier Justification**: The phase creates one markdown file under `specs/decisions/`; the
covering check is the diff read-through, since `bash .claude/scripts/verify-touched.sh` run at
plan time over the existing `specs/decisions/` records reported "0 suite(s) selected, 2 owed",
meaning no suite maps to these paths and nothing narrower exists to name.

**Scope Hypothesis**: The research report's figures (A at 1,572 lines and 61 passing cases; 19
merged pull requests in sf1-engine with 18 by the remote owner; zero `pr/*` remote heads; seven
mechanism rows; `/merge` referenced in 29 files) are carried from
`reports/01_slice-command-design.md` and are hypotheses. Confirm each by the command named in
the task that re-derives it; where the live value differs, the record states the live value and
the difference. B's line count is already known to differ (2,187 live against 2,165 carried).

**Files to modify**:
- `specs/decisions/slice-command-one-path-to-review.md` - created; header and Evidence section

**Verification**:
- The record exists with a non-empty `## Evidence` section.
- Every implementation claim in it carries a file and line range, or a command and its output,
  or a CARRIED-UNVERIFIED mark with a named source.
- The commits read are stated in the section header.
- `git status --short -- agent-system/ .claude/` shows no change made by this phase.

---

### Phase 2: Write the ruling [NOT STARTED]

**Goal**: Add the ruling proper: command surface, mechanism, review base, size bar, survivor and
deletions, and the grant cost, each resting only on Phase 1 evidence.

**Tasks**:
- [ ] `## The command surface`: `/slice [description]`, user-only. State in order what a user
      with no argument and no prior setup sees: the printed resolution (work ref, remote, dirty
      tree line); prompt 1, the target, with where the candidate set is read from (an in-flight
      series, the remote's default branch, bases of the user's open pull requests, free entry)
      and the measured difference shown per candidate; the non-ancestor candidate shown as
      unselectable; the printed bar and its source; prompt 2, the proposal table and its four
      fixed lines; the approve / revise / cancel options; what happens on approval; and what a
      later invocation on an in-flight series does. Rule "one invocation, one target" and how
      "or branches as appropriate" is satisfied by a dependent slice opening against its parent.
- [ ] `## The mechanism`: one script with `check`, `build`, `status`; one series file and its
      fields; the forge call lives in the command file only; proposals are made by the command's
      model and validated mechanically; no inference code. State the default of opening a
      dependent slice after its dependencies merge, and the cost of opening a visible stack
      earlier.
- [ ] `## Basis`: neither existing builder is promoted, with reasons from Phase 1. List the
      design properties carried from the sf1-engine builder (path sets from the work tip,
      exhaustiveness, size check, ancestry refusal, re-derive never rebase, dependency-scoped
      bases). State that consumer-repository builders are retired by their own repositories.
- [ ] `## Review base`: two roles only, work ref and target; no third branch; the `review_base`
      key and the equal-name refusal are removed; the correct emptiness test is an empty diff.
      State where each of the two prior records was right and where wrong.
- [ ] `## The size bar`: a refusal with a recorded-reason escape; source order (declared
      `slice_bar`, else the 75th percentile of merged pull requests on the target when at least
      five exist, else a shipped default printed as unmeasured); lines counted as added lines
      over hand-written paths; the method is portable and the numbers are not, with the Phase 1
      measurements as the ground. State the median as a rejected alternative. Carry the
      research report's CORPUS-UNVERIFIED mark for this repository unless Phase 1 closed it.
- [ ] `## One survivor, and what is deleted`: a table with one row per Phase 1 inventory row
      and a disposition, such that the deletion list is readable as a list of file paths.
      Include the `review_base` section of `context/standards/repo-level-declarations.md`, the
      suite and its classification and manifest rows, `/merge` and the planned stack mode. Rule
      `/merge` removed, not fixed, with the reason.
- [ ] `## Grants`: state the N-push cost, the 600-second window, the `HEAD` binding and its two
      consequences for a plumbing-built ref; name the three pieces of separate work and say the
      design assumes none of them.
- [ ] `## Constraints held`: `rules/pr-prohibition.md` unamended; repo-agnostic deliverables;
      the commit-containment cluster named as an edge and not edited.
- [ ] `## Rejected alternatives`: promote the sf1-engine builder; finish the inference route;
      fix `/merge`; a declared `review_base`; slices as tasks; a portable fixed bar. Each stated
      on its own merits.

**Timing**: 2 hours

**Depends on**: 1

**Verification Tier**: prose

**Tier Justification**: The phase adds prose sections to one markdown file under
`specs/decisions/`; the covering check is the diff read-through, and
`bash .claude/scripts/verify-touched.sh` selects no suite for these paths (plan-time output: "0
suite(s) selected, 2 owed").

**Files to modify**:
- `specs/decisions/slice-command-one-path-to-review.md` - ruling sections added

**Verification**:
- Each section named above is present.
- Every factual claim in a ruling section points at an Evidence row; none introduces a figure
  absent from Evidence.
- The survivor table names exactly one survivor, and every other inventory row has a
  disposition.
- A reader given only this file can list the files to be deleted.

---

### Phase 3: Verdicts, successors and the operator worklist [NOT STARTED]

**Goal**: Give every listed open record a stated disposition on evidence actually read, name the
successors, and tell the operator what to run.

**Tasks**:
- [ ] Read `specs/decisions/batch-worktree-isolation-and-task-squash-landing.md`,
      `specs/decisions/worktree-isolation-removal-verdict.md` and
      `specs/decisions/worktree-isolation-removal-reaffirmation.md` before writing the row for
      the five held records. If they support the research report's "abandon, all five" on the
      ground that a path cut from the tip needs no per-task commit range, rule it and cite the
      passages. If they do not, rule "stays held" and state what would decide it.
- [ ] Read `agent-system/extensions/cslib/commands/pr.md` far enough to rule on it or to state
      precisely why it is outside this ruling (a separate extension's user-invoked command for
      a distinct task type); either way it gets a row rather than a mention.
- [ ] Read the current description and status of each record in `specs/state.json`:
      `handoff_prints_review_stack`, `merge_command_stack_mode`,
      `stack_pr_redeploy_and_second_repo_demo`, `milestone_ref_land_recreates_retired_ref`,
      `branch_aware_orchestration_and_squash_landing`, the five held records, and
      `redeploy_phase_declaration_and_gate_criterion`. Record each one's status and dependency
      edges as read.
- [ ] `## Verdict on each open record`: one row per record with exactly one of "survives
      unchanged", "survives revised", "abandon" (or "stays held" under the fallback above), a
      one-line reason, and for "survives revised" what changes.
- [ ] State the lapsed obligation: the once-per-batch redeploy siting in
      `review-slices-are-declared-tasks.md` existed because each slice was a task, and lapses.
- [ ] `## Successors`: the six named in the research report's R7, each with its territory and
      its ordering edge (the `/slice` build first; `/merge` removal after `/slice` works; the
      generated-path declaration as a hard edge for the bar's line count). State the acceptance
      bar for the first successor: one real slice pushed and opened by the operator.
- [ ] `## Operator worklist`: per verdict row, the command the operator runs to apply it
      (abandon, revise, dependency-edge change, task creation). State that nothing in this list
      was executed by the record's author.
- [ ] `## What is discarded`: an explicit list of things built or planned that this ruling
      discards. It must be non-empty.
- [ ] `## Risks`: whole-file granularity; a slice that omits a file it needs; proposal quality
      resting on the model; the design's own lack of production evidence.

**Timing**: 1.5 hours

**Depends on**: 2

**Verification Tier**: prose

**Tier Justification**: The phase adds prose sections and tables to one markdown file under
`specs/decisions/`; the covering check is the diff read-through, and
`bash .claude/scripts/verify-touched.sh` selects no suite for these paths (plan-time output: "0
suite(s) selected, 2 owed").

**Scope Hypothesis**: The verdict list is ten records (five named individually plus the five
held), with an eleventh, `redeploy_phase_declaration_and_gate_criterion`, touched by the lapsed
obligation. Confirm against the task description's list and `specs/state.json`; a listed record
that is absent or already terminal gets a row saying so rather than being dropped.

**Files to modify**:
- `specs/decisions/slice-command-one-path-to-review.md` - verdict, successor, worklist, discard
  and risk sections added

**Verification**:
- Every record in the task description's verdict list has a row with exactly one disposition.
- The five-held row cites the records read to support it.
- `## What is discarded` names at least one item.
- `git diff --stat -- specs/state.json specs/TODO.md` shows no change made by this phase.

---

### Phase 4: Amend the records the ruling overturns [NOT STARTED]

**Goal**: Make the two existing records point at the new one so no reader acts on an overturned
ruling.

**Tasks**:
- [ ] In the new record, add `## Assertions amended`: one row per amended assertion of
      `review-slices-are-declared-tasks.md` (S3, S4, S5 in part, S6, the retention list, "Why
      not abandon the inference route entirely", the redeploy obligation), each with the
      assertion and what now holds; and a line listing what stands unamended (S1 and S2 as
      outcomes with a changed ground, S7). Add rows for the landing record's L3, L4 and
      review-submission interface as they read after both amendments.
- [ ] In `specs/decisions/review-slices-are-declared-tasks.md` (confirmed present at plan time,
      178 lines), add a dated `**Amended by**` note directly under the opening paragraph naming
      the new record and the amended parts. Change no ruling text in place. If the file is
      absent at implementation time, stop the phase and record the blocker; do not recreate it.
- [ ] In `specs/decisions/isolation-off-landing-verification-and-review-time-squash.md`
      (confirmed present at plan time, with an existing `**Amended by**` note at line 17), add a
      second dated `**Amended by**` note naming the new record for L3, L4 and the
      review-submission interface. If the existing note has moved, anchor on its text, not its
      line number.

**Timing**: 1 hour

**Depends on**: 3

**Verification Tier**: prose

**Tier Justification**: The phase adds amendment notes to two markdown records and a table to a
third, all under `specs/decisions/`; the covering check is the diff read-through confirming no
existing ruling text changed, and `bash .claude/scripts/verify-touched.sh` run at plan time over
exactly the two existing files reported "0 suite(s) selected, 2 owed".

**Files to modify**:
- `specs/decisions/slice-command-one-path-to-review.md` - Assertions amended section
- `specs/decisions/review-slices-are-declared-tasks.md` - dated amendment note
- `specs/decisions/isolation-off-landing-verification-and-review-time-squash.md` - dated
  amendment note

**Verification**:
- `git diff` on the two existing records shows additions only, confined to the amendment notes.
- Every amended assertion named in the old record's note has a row in the new record's table.

---

### Phase 5: Acceptance read-through [NOT STARTED]

**Goal**: Check the finished record against the task's own acceptance criteria and fix what
fails.

**Tasks**:
- [ ] Read the new record start to finish as a reader with no other context, and answer from it
      alone: which single mechanism survives; which files are deleted; whether a review base
      exists; what the size bar is and whether it is portable; the disposition of every listed
      record. Fix any answer the record does not give.
- [ ] Confirm every implementation claim carries a line-numbered citation, a command with
      output, or a CARRIED-UNVERIFIED mark, and that no ruling section contradicts Evidence.
- [ ] Confirm the task description's premise corrections (pull-request counts, the third
      builder, the cslib command, the `--target` override) are each stated in the record.
- [ ] Confirm no file under `agent-system/**` or `.claude/**`, and neither `specs/state.json`
      nor `specs/TODO.md`, was changed by any phase of this plan.
- [ ] Run the scoped touched-path check over the three files this plan touched and record its
      verdict line verbatim.

**Timing**: 0.5 hours

**Depends on**: 4

**Verification Tier**: full

**Files to modify**:
- `specs/decisions/slice-command-one-path-to-review.md` - corrections found in the read-through

**Verification**:
- Scoped touched-path check: `bash .claude/scripts/verify-touched.sh
  specs/decisions/slice-command-one-path-to-review.md
  specs/decisions/review-slices-are-declared-tasks.md
  specs/decisions/isolation-off-landing-verification-and-review-time-squash.md --task-dir
  specs/695_slice_command_design_and_consolidation`, verdict line recorded. An "owed"
  classification is the expected result for these paths and is reported as owed, not as a pass.
- Under `/orchestrate`, the complete gate set is deferred to the orchestration close and is not
  run independently by this phase. In a standalone, non-orchestrated run, this phase runs
  `bash .claude/scripts/verify-deploy.sh` directly.
- All five acceptance questions are answerable from the record alone.

## Testing & Validation

- [ ] The new record exists and contains: Evidence, command surface, mechanism, basis, review
      base, size bar, survivor and deletion table, grants, verdict table, successors, operator
      worklist, what is discarded, assertions amended.
- [ ] Every claim about either implementation is line-cited against a stated commit.
- [ ] Exactly one survivor is named; the deletion list is a list of paths.
- [ ] Every record in the task description's verdict list has one disposition.
- [ ] At least one built or planned thing is named as discarded.
- [ ] The two existing records carry dated amendment notes and no in-place ruling changes.
- [ ] No change under `agent-system/**`, `.claude/**`, `specs/state.json` or `specs/TODO.md`.
- [ ] `bash .claude/scripts/validate-artifact.sh` passes for this plan.

## Artifacts & Outputs

- `specs/decisions/slice-command-one-path-to-review.md` (new)
- `specs/decisions/review-slices-are-declared-tasks.md` (amendment note)
- `specs/decisions/isolation-off-landing-verification-and-review-time-squash.md` (amendment
  note)
- `specs/695_slice_command_design_and_consolidation/summaries/01_slice-command-design-summary.md`

## Rollback/Contingency

All changes are additions to three markdown files under `specs/decisions/`, each committed per
phase. To revert, revert the phase commits; the new record is removed and the two amendment
notes disappear with it. No deployed tree, state file or other repository is touched, so no
further cleanup exists. If Phase 3's reading does not support a verdict the research proposed,
the record rules the weaker verdict and says why; that is a completed phase, not a failure.
