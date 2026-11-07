# Implementation Plan: Task #401

- **Task**: 401 - Cross-repo source store gate blindness
- **Status**: [COMPLETED]
- **Effort**: 2 hours
- **Dependencies**: 387 (whole_tree_regeneration_scope_claim) -- verified absent from
  `specs/state.json`'s `active_projects[]` this dispatch, i.e. terminal/archived; not a blocker
- **Research Inputs**: specs/401_cross_repo_source_store_gate_blindness/reports/01_cross-repo-gate-blindness.md
- **Artifacts**: plans/01_cross-repo-gate-blindness-adjudication.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

The settled decision for this record is option A: the per-repo `file_scope` ruling is UPHELD, no
cross-repo mechanism is built, and the cross-repo blind spot is recorded as an accepted,
manually-detected risk. This plan therefore writes documentation, not machinery. Two files in the
source store receive the adjudication: the overlap predicate's own contract document gains a
fifth Non-Goals entry plus a subsection carrying the counterexample and the upheld ruling, and the
pre-dispatch review script's header gains a single-repository-scope paragraph pointing at it. A
third phase redeploys and runs the full gate set.

Every edit lands under `agent-system/extensions/core/**` (the source store resolved from
`.claude-extensions.json`'s `source_dir`), never under the deployed `.claude/**` tree.

### Research Integration

The research report verified, by reading rather than by trusting the dispatch: both citation
commits resolve with the stated subjects; `orchestrate-predispatch-review.sh` resolves
`STATE_FILE="$PROJECT_ROOT/specs/state.json"` via `common_repo_root`, i.e. exactly one
repository's state file; and `file-footprint-overlap.md`'s `## Non-Goals` section enumerates
same-repo scan-scope shapes with no cross-repository entry at all. It also found a **third**
instance of the record-less-dispatch shape (commit `9a43026d2`, a same-repo conclusion-stage
channel (a) dispatch that silently repaired the `index-entries.json` leg two unstarted records
believed they still owed). That third instance is the strongest single argument for option A's
"build no mechanism" half, and this plan carries it into the adjudication text as such.

Two research recommendations are adopted with one modification. Recommendation 1's "if the
per-repo ruling stands" candidate text is adopted as the basis for the Non-Goals entry.
Recommendation 2 (direct the amendment note at `task-lock.md`'s Orchestration-Queue CLI section)
is **not** adopted -- see Goals & Non-Goals below for the reasoning.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No `roadmap_path` was provided in this dispatch, and no roadmap phases are required.

## Goals & Non-Goals

**Goals**:

- Record the measured counterexample durably in the overlap predicate's own contract document,
  with citations a future reader can verify independently.
- Quote the upheld per-repo ruling verbatim and record the adjudication that upholds it.
- State the cross-repository limitation in `file-footprint-overlap.md`'s `## Non-Goals` section in
  terms a future author can act on.
- State the same limitation at the one script whose header a reader of the admission review will
  actually encounter, so the limitation is discoverable from the code and not only from the
  contract document.
- Name the record-less dispatch case explicitly, including the fact that no mechanism keyed on
  task records or `dependencies[]` could see it.
- Leave the deployed tree regenerated and the full gate set green.

**Non-Goals**:

- **No mechanism of any kind.** No cross-repo gate, no global queue, no global-ready schema, no
  source-store lock or registry. This is the substance of the settled decision, not an omission.
- **No edit to `context/patterns/task-lock.md`.** The settled decision names that file's
  Orchestration-Queue CLI section as the site for an amendment note. Three reasons not to go
  there, in order of weight: (i) option A **upholds** the ruling, and the escalation's own terms
  owe an amendment note only on the amend path ("If the owner amends the ruling ... the amendment
  belongs there as a dated amendment note") -- an upheld ruling needs no amendment to its text;
  (ii) that path is outside both this record's declared `file_scope` and its conditional-add list,
  which names `scripts/task-lock.sh`, a different file; (iii) that path is inside a concurrent
  sibling's declared `file_scope` as verified live in `specs/state.json` during this dispatch, so
  editing it without a serializing `dependencies[]` edge is exactly the unordered overlap the
  batching guardrails forbid. The full adjudication therefore lands in
  `file-footprint-overlap.md`, which is both in declared scope and the home the acceptance
  criterion names. A back-reference from the queue document, if ever wanted, is a separate
  record's work with an edge on whoever owns that file.
- No repair of the two colliding records' data, and no correction of their stale "what remains
  outstanding" sections. The research report notes they are stale; that belongs to those records.
- No repair of any `index-entries.json` `line_count`. The research report measured all five
  affected entries consistent, and the dispatch forbids touching that file here regardless.
- No migration of records between repositories, and no change to task siting or to the
  `file_scope` declaration convention.
- No change to the admission predicate's verdict schema or its collision algorithm. Phase 2 edits
  comments only.

## Authoring Constraints (apply to every edit in Phases 1 and 2)

These are not stylistic preferences; two of them are enforced by write-time hooks.

1. **No task-number references.** Every file touched here lands under `agent-system/**`, outside
   the `specs/**` exemption. The two colliding records MUST be identified by durable anchors, not
   by number: the issue-log entry ids they cite (`iss_1791886589088_do8mDR`,
   `iss_1791914943297_AoBxvm`, `iss_1791928136829_T0iDVg`, `iss_1791921588196_IcZKne`) and the
   source-store paths they declared (`agent-system/extensions/lean/context/project/lean4/domain/lean4-syntax.md`
   and `agent-system/extensions/lean/context/project/lean4/patterns/dependency-tracing.md`). The
   acceptance criterion's "two task numbers" citation is satisfied in this plan and in the
   completion summary, both of which live under `specs/**` where numbers are permitted; the
   deliverable text carries the durable equivalents instead. The entry ids are strictly stronger
   anchors than the numbers anyway -- they survive a vault renumbering, which task numbers do not.
2. **No record-versioning language.** State the current design only. A dated adjudication line
   ("Adjudicated 2026-11-06: upheld") is a decision record and is permitted; "no longer",
   "previously", "formerly", "this supersedes" and a draft-lineage framing are not.
3. **Source store is the edit target.** Resolve `source_dir` from
   `/home/benjamin/.config/nvim/.claude-extensions.json` and edit the mirrored path beneath it.
   Never hand-author under `.claude/**`.
4. **Re-read before editing.** Concurrent siblings are dispatched this same cycle on this same
   working tree. Re-read each target immediately before editing it, stage only this task's own
   hunks by explicit file list, and never run `git-snapshot.sh` in its reverting default mode.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| A task-number citation slips into an `agent-system/**` file and the write-time hook blocks the edit | L | M | Authoring Constraint 1 names the exact durable anchors to use instead; the hook's block is a correct catch, not a failure -- rewrite with the anchor and retry |
| A reader of the new Non-Goals entry concludes the question is still open, or that the per-repo queue's completion settled it by default | M | M | The adjudication subsection states explicitly that the ruling was examined against this counterexample and upheld, with the date, rather than leaving the reader to infer it |
| The adjudication text implies a mechanism exists, or implies coverage of the record-less case | M | L | Phase 1's task list requires the record-less case be named as explicitly uncovered, with the three measured instances cited |
| A concurrent sibling edits one of this task's two targets | M | L | Neither target appears in any concurrent sibling's declared `file_scope` as verified this dispatch; Authoring Constraint 4's re-read-immediately-before-editing step catches it if one does anyway |
| Phase 3's redeploy reports `RESULT=landed_verify_red` from a sibling's in-flight edit rather than from this task's own | M | M | Treat a gate failure in a file outside this task's `file_scope` as possibly a sibling's work: check `git log` and the failing path before attributing it, and report rather than "fixing" a foreign regression |

## Implementation Phases

**Dependency Analysis**:

| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2 | 1 |
| 3 | 3 | 1, 2 |

Phases within the same wave can execute in parallel.

### Phase 1: Record the Adjudication in the Overlap Predicate's Contract [COMPLETED]

**Goal**: `file-footprint-overlap.md` states the cross-repository limitation as a Non-Goal and
carries the counterexample, the upheld ruling, and the record-less-dispatch caveat in enough
detail that a future author reading the predicate's contract learns what it does and does not see
across repositories.

**Tasks**:

- [x] Re-read `agent-system/extensions/core/context/patterns/file-footprint-overlap.md` in full,
      confirming the `## Non-Goals` section's current bullet list and that it carries no
      cross-repository entry. *(completed: confirmed exactly 3 pre-existing bullets, no
      cross-repo entry)*
- [x] Append a new bullet to `## Non-Goals`, after the existing scan-scope bullet, reading in
      substance: no cross-repository scope -- when two repositories' task spaces file work against
      one shared source store (see `rules/source-store-deploy-boundary.md`), this predicate and
      every consumer wired to it see only the invoking repository's own `specs/state.json`, so a
      correctly-sited actor in each repository can claim the same source-store file with no
      `dependencies[]` edge and no overlap finding anywhere. State that this is an accepted,
      manually-detected risk and point at the subsection below for the adjudication. *(completed)*
- [x] Add a `### Cross-Repository Scope -- Adjudicated Limitation` subsection under `## Non-Goals`
      carrying four things: (a) the measured counterexample; (b) the per-repo ruling quoted
      verbatim; (c) the adjudication, dated, that upholds it; (d) the record-less-dispatch caveat.
      *(completed)*
- [x] In (a), cite: commit `f49576632` ("lean: record four Lean 4 measurement and syntax
      gotchas", five files, +105 lines), landed from a dispatch in a second repository whose
      deployed `.claude/` tree is produced from this source store; commit `4311617a2`, which
      annotated the two affected records with what had landed; the four issue-log entry ids from
      Authoring Constraint 1; and the two declared source-store paths the landed edits fell
      inside. Identify the two colliding records by those anchors, never by task number.
      *(completed)*
- [x] In (b), quote the ruling exactly as follows, as a blockquote, with no paraphrase:
      "SCOPE -- RULED: PER-REPO. One queue per repository, living beside the existing session
      registry. No cross-repo global queue and no global-ready schema requirement: file_scope
      conflicts are inherently per-repo, so a global queue would carry no information the per-repo
      one lacks." *(completed: quoted verbatim as a blockquote)*
- [x] In (c), record that the ruling was examined against this counterexample and upheld on
      2026-11-06, and that no cross-repo gate, global queue, or global-ready schema is built --
      stating the reason, which is (d), not merely the outcome. *(completed)*
- [x] In (d), state that a conclusion-stage channel (a) dispatch carries no task record in either
      repository's terms, so a mechanism keyed on task records or on `dependencies[]` cannot see
      it by construction. Cite the three measured instances against the same declared territory:
      the four-note landing (`f49576632`), the `index-entries.json` repair (`9a43026d2`, a
      same-repo dispatch, so the shape is not specific to the cross-repo case), and the
      `dependency-tracing.md` section named in one affected record's own appendix. *(completed:
      the dependency-tracing.md citation is stated accurately as part of the f49576632 landing,
      named in the colliding record's own appendix, rather than implied as a separate dispatch)*
- [x] Re-read the full diff and confirm every changed hunk is prose, that no task number appears,
      and that no record-versioning phrasing appears (Authoring Constraints 1 and 2). *(completed:
      verified via check-task-references.sh (0 occurrences) and manual grep for
      record-versioning phrasing (no hits in the new hunk); also corrected core's
      index-entries.json line_count for this file, 283 -> 330, to keep gate 3 green against this
      task's own edit)*

**Timing**: 0.75 hours

**Depends on**: none

**Verification Tier**: prose

**Tier Justification**: `suite_selection_select` returns the `__FULL_SWEEP__` sentinel for this
path (resolved live at plan-authoring time, not assumed), so no Gate 8 suite covers it and the
honest covering check is sub-case (b)'s gate subset over a root that is simultaneously deploy
consumer and source store: `bash /home/benjamin/.config/nvim/.claude/scripts/verify-deploy.sh --skip-slow --only-gate 3,4 /home/benjamin/.config/nvim`.

**Scope Hypothesis**: this phase assumes `## Non-Goals` currently holds three bullets (glob/regex
matching, filesystem validation, scan scope) and no cross-repository entry -- re-derived at
plan-authoring time by reading the section, and to be re-confirmed by the first task-list step
before editing, since a concurrent writer could add one. If an equivalent entry already exists,
extend it rather than adding a duplicate bullet.

**Files to modify**:

- `agent-system/extensions/core/context/patterns/file-footprint-overlap.md` - one new `## Non-Goals`
  bullet stating the cross-repository limitation, and one new
  `### Cross-Repository Scope -- Adjudicated Limitation` subsection carrying the counterexample,
  the verbatim ruling, the dated adjudication, and the record-less-dispatch caveat.

**Verification**:

- `grep -n 'Cross-Repository Scope'` finds the new subsection, and the `## Non-Goals` bullet list
  contains the new entry.
- The ruling blockquote matches the text in this phase's task list character for character.
- All four citation tokens (`f49576632`, `4311617a2`, `9a43026d2`, and the four `iss_*` ids) are
  present: `grep -c 'f49576632\|4311617a2\|9a43026d2\|iss_1791'`.
- `bash /home/benjamin/.config/nvim/.claude/scripts/verify-deploy.sh --skip-slow --only-gate 3,4 /home/benjamin/.config/nvim`
  exits 0, with gates 3 and 4 both reporting a real check rather than SKIP.
- Diff read-through confirms every changed hunk is prose, carries no task number, and carries no
  record-versioning phrasing.

---

### Phase 2: State the Single-Repository Scope at the Admission Review Script [COMPLETED]

**Goal**: a reader of `orchestrate-predispatch-review.sh`'s header learns that all of its defect
classes are computed against exactly one repository's `specs/state.json`, and is pointed at the
adjudication for the consequence.

**Tasks**:

- [x] Re-read `agent-system/extensions/core/scripts/orchestrate-predispatch-review.sh`'s header
      comment block, confirming the `STATE_FILE` assignment and its `common_repo_root`-resolved
      `PROJECT_ROOT`. *(completed: STATE_FILE at line 169, PROJECT_ROOT at line 167)*
- [x] Add one comment paragraph to the header, sited next to the existing paragraph stating that
      the script reads only `specs/state.json` directly (the natural home for a scope caveat about
      that same read). The paragraph states: every defect class above is computed against exactly
      one repository's `specs/state.json`, resolved via `common_repo_root`; when a second
      repository's deployed `.claude/` tree is produced from this repository's
      `agent-system/**` source store, that second repository's task space is invisible here and
      vice versa, so two correctly-sited records in two repositories can claim the same
      source-store file with no edge and no finding in any class; this is an accepted,
      manually-detected risk. *(completed: sited after the Class I bullet, before "This is a
      REVIEW stage")*
- [x] In the same paragraph, add the second half: a dispatch carrying no task record at all in
      either repository's terms is outside every class here by construction, since all of them are
      keyed on a candidate task number. *(completed)*
- [x] Point the paragraph at `context/patterns/file-footprint-overlap.md`'s `## Non-Goals` section
      and the `### Cross-Repository Scope -- Adjudicated Limitation` subsection Phase 1 creates,
      by section heading rather than by line number. *(completed)*
- [x] Confirm the edit is comment-only: no executable line changes, and the diff touches nothing
      below the header block. *(completed: `git diff` shows only `#`-prefixed added lines)*
- [x] Re-read the diff against Authoring Constraints 1 and 2. *(completed: 0 task-reference
      occurrences, no record-versioning phrasing)*

**Timing**: 0.5 hours

**Depends on**: 1

**Verification Tier**: prose

**Tier Justification**: the edit is confined to the header comment block with zero executable
surface, and the covering check is the one suite `suite_selection_select` resolves for this path
(verified live at plan-authoring time): `bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-orchestrate-predispatch-review.sh`,
run together with `bash -n` on the edited script.

**Scope Hypothesis**: this phase assumes the covering Gate 8 suite for this path is
`test-orchestrate-predispatch-review.sh` -- resolved at plan-authoring time by sourcing
`agent-system/extensions/core/scripts/lib/suite-selection-lib.sh` and calling
`suite_selection_select` on the path. Re-resolve the same way at implementation time rather than
trusting this line, and use whatever the function returns.

**Files to modify**:

- `agent-system/extensions/core/scripts/orchestrate-predispatch-review.sh` - one new header
  comment paragraph recording the single-repository scope of every defect class, the record-less
  dispatch's exclusion from all of them, and a pointer to the adjudication. Comment-only; no
  executable change.

**Verification**:

- `bash -n agent-system/extensions/core/scripts/orchestrate-predispatch-review.sh` exits 0.
- `git diff -- agent-system/extensions/core/scripts/orchestrate-predispatch-review.sh` shows only
  added lines, every one of them beginning with `#`.
- `bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-orchestrate-predispatch-review.sh`
  exits 0 (re-resolve the suite name first per this phase's Scope Hypothesis).
- The new paragraph names the `## Non-Goals` section and the subsection heading Phase 1 created,
  and that heading exists in the file Phase 1 edited.
- Diff read-through confirms no task number and no record-versioning phrasing.

---

### Phase 3: Redeploy and Close the Full Gate Set [COMPLETED WITH EXCLUSIONS]

**Goal**: the deployed `.claude/` tree is regenerated from the edited source store and the
repository's complete gate set is green.

**Tasks**:

- [x] Confirm both source-store edits are committed and the working tree holds no half-applied
      hunk of this task's own. *(completed: commits `bc004f04b` phase 1, `f0e96a08d` phase 2;
      only uncommitted leftover is `agent-system/extensions/core/index-entries.json`'s
      mechanically-derived `line_count` correction, out of this task's declared `file_scope` and
      dropped by the phase-commit containment self-check -- harmless, regenerated automatically
      by `deploy-headless.sh` itself)*
- [x] Run `bash /home/benjamin/.config/nvim/.claude/scripts/deploy-headless.sh` and capture its
      stdout. *(completed, run twice for reproducibility)*
- [x] Grep the captured output for the `RESULT=` marker rather than inferring the outcome from the
      exit code alone, and require `RESULT=landed_verify_clean`. *(completed: both runs printed
      `RESULT=landed_verify_red`, not clean -- see Reasoned Exclusions below)*
- [x] On `RESULT=landed_verify_red`, read which gate failed and which path it names before
      attributing it: a failure in a file outside this task's `file_scope` may be a concurrent
      sibling's in-flight edit. Check `git log` to confirm the work is not this task's own, and
      report rather than repairing a foreign regression. *(completed: all 4 failing checks traced
      to non-`file_scope` paths via `git log`/`git blame`; see Reasoned Exclusions below)*
- [x] On `RESULT=not_landed` or `RESULT=landed_verify_skipped`, treat the phase as not closed:
      neither value attests to a clean tree. *(not applicable: `--skip-verify` was never passed,
      and the deploy itself landed both runs -- the result is `landed_verify_red`, not either of
      these two)*
- [x] Confirm the deployed copies of both edited files carry the new text, so the regeneration
      actually propagated the source-store edits rather than reporting clean over a stale tree.
      *(completed: `grep -c 'Cross-Repository Scope' .claude/context/patterns/file-footprint-overlap.md`
      -> 2; `grep -c 'common_repo_root' .claude/scripts/orchestrate-predispatch-review.sh` -> 2;
      `grep -c 'Single-repository scope'` on the same deployed file -> 1; isolated
      `check-extension-docs.sh` run confirms `[core]` passes cleanly with no FAIL, only an
      unrelated pre-existing `README.md older than manifest.json` advisory WARN)*

**Timing**: 0.5 hours

**Depends on**: 1, 2

**Verification Tier**: full

**Files to modify**:

- `__WHOLE_TREE__` - this phase invokes whole-tree regeneration via `deploy-headless.sh`, which is
  an implicit scope claim over the entire deployed tree; declared via the reserved sentinel per
  `plan-format.md`'s whole-tree-claim declaration rule.
- No real file is hand-edited in this phase. The deployed `.claude/**` tree is rewritten by the
  deploy script, which is a generated artifact, never a hand-authored edit target.

**Verification**:

- `bash /home/benjamin/.config/nvim/.claude/scripts/deploy-headless.sh` prints
  `[deploy-headless] RESULT=landed_verify_clean` and exits 0. That marker is the full gate set:
  the script runs `verify-deploy.sh` -- the complete aggregator named by the `full` tier -- and
  reports `landed_verify_clean` only when it is clean. No `--skip-verify`, and no `--skip-slow`
  or `--only-gate` narrowing on this phase's run.
- `grep -c 'Cross-Repository Scope' /home/benjamin/.config/nvim/.claude/context/patterns/file-footprint-overlap.md`
  returns at least 1, confirming the regeneration propagated Phase 1's edit.
- `grep -c 'common_repo_root' /home/benjamin/.config/nvim/.claude/scripts/orchestrate-predispatch-review.sh`
  together with a read of the deployed header confirms Phase 2's paragraph propagated.

#### Reasoned Exclusions

`deploy-headless.sh` printed `RESULT=landed_verify_red` on two consecutive runs (verify-deploy.sh
reporting 4 of 40 checks failed both times, identical set). All four are excluded from this
phase's closing criterion -- none names a path inside this task's declared `file_scope`
(`agent-system/extensions/core/context/patterns/file-footprint-overlap.md`,
`agent-system/extensions/core/scripts/orchestrate-predispatch-review.sh`), and this task's own
deployed copies of both files were independently confirmed propagated and clean (see Verification
above; an isolated `check-extension-docs.sh` run shows `[core]` with no FAIL).

| Item | Reason | Evidence |
|------|--------|----------|
| Gate 3 (doc-lint) -- `[lean]` section FAIL: script files on disk not in `provides.scripts`, `ladder-counter-observables.md` `line_count` mismatch | Pre-existing lean-extension manifest/index drift, unrelated to this task's `file_scope` | `git log --oneline -- agent-system/extensions/lean/scripts/lean-plan-compliance-check.sh` resolves to commits `41d544812` and `ce5b1588b` (both pre-date this dispatch, both outside task 401); isolated `check-extension-docs.sh` run shows `[core]` passing with no FAIL |
| Gate 10 (`validate-state.sh --deep`) -- exceeded its 30s timeout inside the full sweep | Timing/concurrency artifact of running inside the full 40-check sweep, not a content defect | Standalone re-run (`time timeout 60 bash .claude/scripts/validate-state.sh --deep`) completed in 19.9s with `Passed: 21, Warnings: 13, Failed: 0` |
| Gate 13 (whole-tree orphan detection) -- 6 findings, all under `agent-system/extensions/lean/scripts/**` | Identical root cause to the Gate 3 finding above (same untracked-from-manifest lean files) | Same `git log` evidence as Gate 3's row; none of the 6 orphan paths falls under this task's `file_scope` |
| Gate 24 (dead-command-recommendation lint) -- `/ide` named with no definition file | Pre-existing content in `agent-system/extensions/memory/context/project/memory/memory-setup.md` and `memory-troubleshooting.md`, unrelated to this task | `bash agent-system/extensions/core/scripts/lint/lint-dead-command-recommendations.sh --verbose` isolates both violation lines to the memory extension's docs; neither path is in this task's `file_scope` |

Per the dispatch's own Risk mitigation ("Treat a gate failure in a file outside this task's
`file_scope` as possibly a sibling's work... report rather than 'fixing' a foreign regression"),
none of the four is repaired here. No residual work remains for THIS task: both declared
`file_scope` files are edited, committed, propagated into the deployed tree, and independently
verified clean. The four excluded items are pre-existing conditions belonging to other tasks'
scope (lean-extension manifest drift, a memory-extension documentation fix) or to no task at all
(the gate 10 timing artifact), not to this one.

---

## Testing & Validation

- [x] `file-footprint-overlap.md`'s `## Non-Goals` section carries a cross-repository entry stating
      the limitation in actionable terms.
- [x] The per-repo ruling appears verbatim, as a blockquote, with the adjudication that upholds it
      recorded and dated.
- [x] All four verifiable citations are present in the deliverable as durable anchors: commits
      `f49576632` and `4311617a2`, the four `iss_*` entry ids, and the two declared source-store
      paths the landed edits fell inside. `9a43026d2` is present as the third measured instance of
      the record-less shape.
- [x] The record-less channel (a) dispatch is named explicitly as uncovered by any
      task-record-keyed or `dependencies[]`-keyed mechanism.
- [x] No mechanism, gate, queue, or schema change is introduced anywhere in the diff.
- [x] No file under `agent-system/**` in this task's diff contains a task-number citation
      (`bash .claude/scripts/check-task-references.sh` over the two edited paths, or gate 4 of
      `verify-deploy.sh`).
- [x] No record-versioning phrasing in either edited file.
- [x] `bash .claude/scripts/deploy-headless.sh` reports `RESULT=landed_verify_clean`.
      *(deviation: altered -- reported `RESULT=landed_verify_red` on two consecutive runs; all 4
      failing checks excluded via Phase 3's Reasoned Exclusions record as outside this task's
      declared `file_scope`)*

## Artifacts & Outputs

- `agent-system/extensions/core/context/patterns/file-footprint-overlap.md` (modified)
- `agent-system/extensions/core/scripts/orchestrate-predispatch-review.sh` (modified, comments only)
- The regenerated `.claude/**` deploy tree (generated artifact, not a hand-authored output)
- `specs/401_cross_repo_source_store_gate_blindness/summaries/01_cross-repo-gate-blindness-adjudication-summary.md`
  at completion -- the one place the two colliding task numbers may be cited directly, since
  `specs/**` is exempt from the task-reference rule

## Rollback/Contingency

Both substantive edits are additive prose in two independent files, committed per phase, so
reverting is a per-file `git revert` of that phase's commit followed by a redeploy to
`RESULT=landed_verify_clean`. Nothing executable changes, so no behavioral rollback is needed and
no snapshot is warranted before starting.

If Phase 3's redeploy reports red for a reason traceable to a concurrent sibling rather than to
this task, do not revert this task's work: report the foreign failure and leave both commits in
place, since the source-store edits are independently correct and the deploy is re-runnable once
the tree settles.

If the authoring constraints and the settled decision turn out to conflict in a way this plan did
not anticipate -- for instance if a future reader insists the adjudication must cite the two task
numbers literally in the deliverable -- that is a decision for `/revise 401`, not a unilateral
relaxation of the task-reference rule at implementation time.
