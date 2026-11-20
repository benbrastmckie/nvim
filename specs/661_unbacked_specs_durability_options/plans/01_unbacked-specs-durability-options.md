# Implementation Plan: Task #661

- **Task**: 661 - Unbacked specs durability options
- **Status**: [COMPLETED]
- **Effort**: 0.75 hours
- **Dependencies**: None
- **Research Inputs**: specs/661_unbacked_specs_durability_options/reports/01_unbacked_specs_durability.md
- **Artifacts**: plans/01_unbacked-specs-durability-options.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

The research report already discharges both halves of this task's `DONE WHEN` clause: it states
the four named options, scores each against the five criteria with the churn criterion applied
first, recommends one (Option D -- document the exposure, build nothing), and drafts the
durability statement under its "Recommendation for Placement" heading. What remains is therefore
not design work: it is one verification-and-attestation pass plus one completion summary that
carries the drafted statement verbatim so the documentation record can place it without
re-deriving anything.

That is a single, indivisible unit of roughly forty-five minutes producing exactly one new file,
so this plan declares one phase. A two-phase split here would be decoration: the verification
verdict and the summary that records it cannot usefully be committed apart, because a failed
verification changes what the summary says rather than adding a second deliverable.

This task builds nothing and writes nothing under `agent-system/**`. Its declared `file_scope` is
empty by design (confirmed empty in `specs/state.json` at planning time), and every file this
plan touches lies under this task's own `specs/` artifact directory -- derived output, never a
`file_scope` excursion.

### Research Integration

- The recommendation is settled and is not reopened by this plan: Option D. Options A (sibling
  repository) and B (orphan-branch archive commit) both fail the disqualifying criterion -- each
  creates a second place the specs tree must live, which is a branch, remote, or repository that
  every branch- or repo-enumerating surface must then learn to skip, the exact cost class the
  ignored posture exists to remove. Option C (an external host-level sync or snapshot) is the one
  candidate that touches git not at all, but it fails on a different ground: it is neither
  buildable nor verifiable from inside this project, so it collapses into Option D plus a line
  telling the reader to check their own host.
- The report's drafted durability statement is written in the negative ("No commit, branch, or
  repository preserves them") precisely so it cannot be misread as a feature. The summary must
  carry it verbatim rather than paraphrase it, or that property is lost in transit.
- The report records that no mechanism backing up an ignored specs tree exists anywhere in this
  codebase today, and that the two nearest analogues (`settings_backup.lua`'s same-filesystem
  pre-wipe snapshot, and the Literature extension's global reference repository) do not transfer:
  neither matches a write pattern of many small mutations per dispatch.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No `roadmap_path` was provided in this dispatch's delegation context, so no roadmap consultation
was performed and no roadmap phases are added.

### Premise Re-Validation

Both lines the dispatch extracted as carried-figure trigger shapes were checked against live
state, and both are confirmed unchanged:

1. *"SOURCE STORE IS THE EDIT TARGET: agent-system/extensions/core/\*\*"* -- confirmed.
   `.claude-extensions.json` resolves `extensions.core.source_dir` to
   `/home/benjamin/.config/nvim/agent-system/extensions/core`, and that directory exists on disk.
   The claim is accurate, though vacuous for this task in particular, which writes no file there.
2. *"This record's file_scope is deliberately EMPTY"* -- confirmed. The record's `file_scope` in
   `specs/state.json` is the empty array. It was not re-broadened, and this plan does not broaden
   it: no phase below declares a path under `agent-system/**`, and neither
   `context/standards/` nor `context/standards/orchestrator-runtime-files.md` is declared by any
   phase. Reading a standards file to author this plan is not declaring it.

No `project/**` context entry matching this dispatch's `task_type` (`meta`) and the
`plan-authoring` keyword exists in the deployed context index -- the only `plan-authoring` entry
is `project/lean4/patterns/plan-authoring-gate-collisions.md`, scoped to the `lean4` task type.
Zero hits is the expected result for this task type.

## Goals & Non-Goals

**Goals**:
- Confirm, against the report as it actually stands, that both `DONE WHEN` clauses are satisfied:
  the per-option verdicts against all five named criteria, and a drafted durability statement fit
  for a reader of the rules.
- Produce the completion summary, carrying the drafted durability statement verbatim and naming
  its exact source path, so the documentation record that places it needs no search and no
  re-derivation.
- Leave the recommendation stated without hedging, as the task description explicitly permits:
  document the exposure and build nothing is the outcome.

**Non-Goals**:
- Designing any durability mechanism, writing any script, or adding any hook. The task
  description forbids all three, and the recommendation is to build nothing, so there is nothing
  to design even if it were permitted.
- Placing the durability statement into any rules or documentation surface. Placement belongs to
  the documentation record, whose own `DONE WHEN` names it and whose `file_scope` already covers
  the receiving surfaces. This task drafts and hands over; it does not place.
- Editing any other record's description or `file_scope` in `specs/state.json` to make the
  handoff mechanical. See Risks & Mitigations for why that was weighed and rejected.
- Touching any file under `agent-system/**`, or re-broadening this record's empty `file_scope`.
- Re-opening the Option A/B/C/D comparison. It is settled in the report; the summary records the
  verdict rather than re-litigating it.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| The summary paraphrases the durability statement instead of quoting it, losing the deliberate negative framing that keeps it from reading as a feature | M | M | The phase task list requires a byte-level comparison of the quoted block against the report's own text, not a read-through |
| The documentation record's implementer cannot find the drafted statement, since its own description names only "the research task" without a path | M | M | The summary names the report path and the exact heading the statement sits under, and quotes the statement in full, so the statement is reachable from the durable summary alone |
| An attempt to make the handoff mechanical by editing the documentation record's description rewrites `specs/state.json` under live sibling concurrency | H | L | Rejected, not mitigated: there is no sanctioned script for editing another record's description, and a hand-rolled jq rewrite reflows every record's formatting in that file while a sibling task is dispatched this same cycle. The report-plus-summary handoff above is sufficient and carries none of that risk |
| A future reader reverses the recommendation without re-deriving why A and B lost | M | M | Already mitigated in the report, which names the disqualifying criterion rather than only the conclusion; the summary repeats the criterion alongside the verdict |
| A sibling task dispatched this same cycle has edits in flight in this shared working tree | M | M | Only this task's own `specs/661_*` files are staged and committed, by explicit file list; no directory or glob add; no reverting `git-snapshot.sh` |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |

This plan has one phase, which is therefore its final phase.

### Phase 1: Verify the report against DONE WHEN and write the completion summary [COMPLETED]

**Goal**: Attest that the research report satisfies both `DONE WHEN` clauses, then write the
completion summary that records the verdict and hands the drafted durability statement to the
documentation record in a form that needs no re-derivation.

**Tasks**:
- [ ] Re-read `specs/661_unbacked_specs_durability_options/reports/01_unbacked_specs_durability.md`
      in full. Confirm clause one: all four named options appear (sibling repository; orphan-branch
      archive commit; external host-level sync or snapshot; document and build nothing), and each
      carries a verdict against all five criteria -- setup cost, per-task cost, what it recovers,
      what it silently fails to recover, and the cross-branch-churn criterion applied first. Note
      any option missing a criterion.
- [ ] Confirm clause two: a short durability statement suitable for a reader of the rules is
      drafted, and is self-contained enough to place without surrounding context. It sits under
      the report's "Recommendation for Placement" heading.
- [ ] Re-confirm, against live state rather than against this plan, that `file_scope` for this
      record in `specs/state.json` is still the empty array, and that nothing under
      `agent-system/**` has been modified by this task.
- [ ] Write `specs/661_unbacked_specs_durability_options/summaries/01_unbacked-specs-durability-options-summary.md`
      with the metadata fields `summary-format.md` requires (`Task`, `Status`, `Started`,
      `Completed`, `Artifacts`, `Standards`) and its six required sections (`Overview`,
      `What Changed`, `Decisions`, `Impacts`, `Follow-ups`, `References`).
- [ ] In that summary's `Decisions` section, state the recommendation without hedging -- Option D,
      document the exposure and build nothing -- and name the disqualifying criterion that rules
      out Options A and B, plus the separate unverifiability ground that rules out Option C.
- [ ] In that summary's `What Changed` section, state plainly that no mechanism was built, no
      script written, and no hook added, and that no file under `agent-system/**` was touched --
      this is the task's intended outcome, not an incomplete one.
- [ ] Quote the drafted durability statement in full in the summary, as a blockquote, and name
      both its source path and the "Recommendation for Placement" heading it sits under.
      Compare the quoted block against the report's own text byte-for-byte before committing;
      a paraphrase is a defect here, not a stylistic choice.
- [ ] In that summary's `Follow-ups` section, name the documentation record as the recipient
      that places the statement, and record that this task deliberately does not place it and
      deliberately does not edit that record's description to point at this path.
- [ ] Run `bash .claude/scripts/validate-artifact.sh specs/661_unbacked_specs_durability_options/summaries/01_unbacked-specs-durability-options-summary.md summary`
      and resolve any reported error before committing.
- [ ] Stage and commit by explicit file list only -- the summary and this plan file, never a
      directory or glob pathspec -- via `bash .claude/scripts/git-commit-scoped.sh`.

**Timing**: 0.75 hours

**Depends on**: none

**Verification Tier**: full

**Commit Mode**: per-substep

**Scope Hypothesis**: this phase writes exactly one new file, the summary named above, and
modifies no other file -- in particular nothing under `agent-system/**` and nothing in any other
task's `specs/` directory. Confirm at implementation time with `git status --short` before
staging: any path outside `specs/661_unbacked_specs_durability_options/` is either a sibling
task's in-flight edit, to be left alone and reported, or a defect in this phase's execution.

**Files to modify**:
- `specs/661_unbacked_specs_durability_options/summaries/01_unbacked-specs-durability-options-summary.md` - new; the completion summary, carrying the verdict and the verbatim durability statement
- `specs/661_unbacked_specs_durability_options/plans/01_unbacked-specs-durability-options.md` - this plan file; phase status marker advanced on closure

**Verification**:
- Both `DONE WHEN` clauses explicitly attested against the report's actual text, with the result
  stated even where it only confirms the clause satisfied.
- `bash .claude/scripts/validate-artifact.sh specs/661_unbacked_specs_durability_options/summaries/01_unbacked-specs-durability-options-summary.md summary`
  exits 0.
- The quoted durability statement matches the report's own text byte-for-byte.
- `git status --short` shows no modification under `agent-system/**` attributable to this task,
  and this record's `file_scope` in `specs/state.json` is still the empty array.
- Scoped touched-path check for this phase's own declared files:
  `bash .claude/scripts/verify-touched.sh specs/661_unbacked_specs_durability_options/summaries/01_unbacked-specs-durability-options-summary.md specs/661_unbacked_specs_durability_options/plans/01_unbacked-specs-durability-options.md`.
  Every declared path lies under `specs/**`, where the suite selector returns `__FULL_SWEEP__`
  for the whole set (run at planning time over both paths; sentinel-only output, so no suite
  covers either file) -- which is why the `validate-artifact.sh` run above, plus a diff
  read-through of the staged hunks, is the substantive check that actually reaches this phase's
  content. `--only-gate 3,4` is deliberately not named: `specs/**` is the task-reference lint's
  own exempt tree, and doc-lint has no bearing on `specs/**` content.
- The complete gate set is NOT independently invoked by this phase. It remains owed once per
  `/orchestrate` invocation and is explicitly deferred to the orchestration close, which
  discharges it; this phase records that deferral in its own verification notes rather than
  running a full battery of its own.

---

## Testing & Validation

- [ ] Report re-read in full; both `DONE WHEN` clauses attested explicitly, satisfied or not.
- [ ] All four options confirmed present in the report, each with a verdict against all five
      criteria, with the churn criterion applied first.
- [ ] Summary exists and `validate-artifact.sh ... summary` exits 0.
- [ ] Durability statement quoted verbatim, byte-for-byte against the report.
- [ ] Recommendation stated without hedging; the build-nothing outcome stated as complete rather
      than as a shortfall.
- [ ] No file under `agent-system/**` modified; `file_scope` still the empty array.
- [ ] Commit staged by explicit file list; no directory or glob pathspec.

## Artifacts & Outputs

- `specs/661_unbacked_specs_durability_options/summaries/01_unbacked-specs-durability-options-summary.md`
  -- the completion summary, carrying the verdict, the unhedged recommendation, and the verbatim
  durability statement with its source path and heading.
- `specs/661_unbacked_specs_durability_options/plans/01_unbacked-specs-durability-options.md`
  -- this plan, with its phase marker advanced on closure.
- No new or modified file under `agent-system/**`. This is the intended output set, complete as
  stated.

## Rollback/Contingency

The only new file is the summary, and the only modification is this plan's own phase marker, both
under this task's `specs/` directory. To revert, delete the summary and restore the plan's marker;
nothing outside `specs/661_unbacked_specs_durability_options/` changes, so no deploy, no
regeneration, and no source-store edit has to be undone.

If the verification pass finds the report short of either `DONE WHEN` clause -- an option missing
a criterion, or a durability statement too context-dependent to place -- the contingency is to
close this phase `[COMPLETED WITH EXCLUSIONS]`, state exactly which clause failed and why in the
summary, and leave the gap named rather than silently patching the research report from inside
an implementation phase. A substantive gap in the report's own analysis is a research deficiency
and belongs to a research round, not to this one.
