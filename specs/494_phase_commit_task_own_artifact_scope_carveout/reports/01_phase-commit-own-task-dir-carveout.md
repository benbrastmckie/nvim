# Research Report: Exempt a task's own artifact directory from the phase-commit containment predicate

**Task**: 494 - Exempt a task own artifact directory from the phase-commit containment predicate
**Started**: 2026-11-05T00:00:00Z
**Completed**: 2026-11-05T00:30:00Z
**Effort**: small (one script, one shared-doc update, one test file)
**Dependencies**: None (this record is the predecessor; tasks 430 and 486 each depend on it)
**Sources/Inputs**:
- `agent-system/extensions/core/scripts/git-commit-phase.sh` (full read)
- `agent-system/extensions/core/context/standards/git-staging-scope.md` ("Staging-Layer
  Containment Filter" / "Three Containment sites, not one" sections)
- `agent-system/extensions/core/scripts/git-commit-scoped.sh` (V10 containment_scope_arr, lines
  ~460-530)
- `agent-system/extensions/core/scripts/orchestrate-cycle-postflight.sh` (WORK (h), lines
  ~1625-1680)
- `agent-system/extensions/core/scripts/lib/engine-written-state-paths-lib.sh` (full read)
- `agent-system/extensions/core/scripts/lib/task-lookup-lib.sh` (full read)
- `agent-system/extensions/core/scripts/orchestrator-postflight.sh` (Stage 7, `--file-scope-add`
  write-back)
- `agent-system/extensions/core/scripts/plan-file-scope-harvest.sh` (header/contract)
- `agent-system/extensions/core/scripts/tests/test-git-commit-phase.sh` (case inventory)
- `specs/state.json` (tasks 430, 486, 494 entries — dependency confirmation)
**Artifacts**:
- This report: `specs/494_phase_commit_task_own_artifact_scope_carveout/reports/01_phase-commit-own-task-dir-carveout.md`
**Standards**: report-format.md, source-store-deploy-boundary.md, git-staging-scope.md

## Executive Summary

- The defect is confirmed exactly as the dispatch describes: `git-commit-phase.sh`'s
  Phase-Commit Containment Self-Check widens `file_scope_arr` with the shared
  engine-written-state allowlist but never with the dispatching task's own resolved directory,
  unlike the two sibling Containment sites (`orchestrate-cycle-postflight.sh` WORK (h) and
  `git-commit-scoped.sh`'s V10), which both already carry that member.
- The fix is a one-array-element addition at the existing non-empty `file_scope_arr` guard
  (around current lines 247-270): splice `"${task_dir}/"` in alongside the engine-written-state
  widening, mirroring sites 1 and 3's own wording and placement.
- The "missing_key-yet-dropped" question is resolved: `orchestrator-postflight.sh` Stage 7
  writes `file_scope` via `--file-scope-add` from research's `proposed_file_scope` or
  `plan-file-scope-harvest.sh`'s harvested "Files to modify" union — both source-only, never a
  task directory. A task genuinely `missing_key` at pre-dispatch review (before research runs)
  can legitimately acquire a non-empty `file_scope` by the time a later phase commit fires, via
  this additive write landing in between. This is a point-in-time difference, not a fail-open
  defect: no change to the fail-open posture is warranted or in scope.
- The WHERE ruling (shared library vs. per-site splice) is settled by documentary evidence, not
  just precedent: `engine-written-state-paths-lib.sh`'s own header explicitly lists "any
  task-owned `specs/{NNN}_*/` path" as a **rejected candidate** for that shared allowlist,
  reasoning that a task's own directory "belongs in that task's own declared `file_scope`, not
  in a universal allowlist that bypasses the declaration mechanism entirely." Sites 1 and 3 both
  already implement this as a **per-site splice** (not a shared-lib member) for exactly this
  reason. Site 2 must follow the same shape.
- `git-staging-scope.md`'s existing "Three Containment sites, not one" subsection already
  documents this exact gap in its own closing paragraph ("Site 2... never received it") and
  additionally documents a claim worth correcting in the same edit: it says V10 (site 3)
  "structurally subsumes site 2's own reach" because `git-commit-phase.sh` always forwards
  `--task`. That subsumption claim holds for the **shared engine-written-state allowlist gap**
  (which V10 already closes system-wide) but does **not** hold for the missing task-directory
  member specifically: site 2 removes an uncontained path from its own `stage_paths` pathspec
  *before* ever invoking `git-commit-scoped.sh`, so V10 never gets a chance to see — let alone
  restore — a path site 2 already dropped. The observed live incident is precisely that: the
  warning text in the symptom ("not contained in this task's declared file_scope") is site 2's
  own wording, confirming the drop happened upstream of V10.
- `test-git-commit-phase.sh` already has 14 cases (through Case 14) covering the derivation,
  containment-port, and fail-open behavior this defect must not disturb; the acceptance fixtures
  slot in as new, numbered cases following that file's existing style (synthetic task 999,
  `common_test_pass`/`common_test_fail` helpers).

## Context & Scope

This research covers only `git-commit-phase.sh`'s Phase-Commit Containment Self-Check (site 2 of
three), its governing doc section in `git-staging-scope.md`, and the upstream mechanism
(`orchestrator-postflight.sh` Stage 7's `--file-scope-add` write-back) that explains why a
`missing_key` task can still see a drop later. It does not touch sites 1 or 3 themselves (both
already carry the fix), does not touch the fail-open posture (confirmed correct and
out-of-scope to change), and does not touch the unrelated territory of tasks 430 (stale
hand-authored `file_scope` for source paths) or 486 (extension manifest registration) — both of
which depend on this record per their own `dependencies` arrays in `specs/state.json`
(`430: [362,394,395,425,428,494]`, `486: [430,446,484,494]`).

## Findings

### The asymmetry, read directly from the source store

`agent-system/extensions/core/scripts/git-commit-phase.sh`:

- Line 193: `task_dir="specs/${padded_num}_${project_name}"` — a plain string built from
  `--task`/`--project`, not routed through `task-lookup-lib.sh`'s archive-aware
  `task_lookup_dir()`. This is a pre-existing local simplification (a phase commit only ever
  fires mid-dispatch against an active, non-archived task, so archive-awareness has no bearing
  here); it is not itself part of this defect and is noted only because sites 1 and 3 both
  *do* go through the archive-aware helper — the local var is simply already in hand at site 2,
  which if anything makes the fix simpler there, not harder.
- Line 201: `stage_paths=("${task_dir}/" "specs/TODO.md" "specs/state.json")` — the task's own
  directory IS staged unconditionally. This construct sits structurally outside the
  Containment Self-Check (per the script's own lines 196-200 comment) and is correct; the hard
  constraints forbid touching it.
- Lines 237-270: the Containment Self-Check. Gated on `file_scope_json` being present,
  non-null, and non-`"[]"` (line 241). Inside that guard, `file_scope_arr` is widened only with
  `engine_written_state_paths()`'s four-member array (or, on a source/parse failure, the
  hardcoded `("specs/TODO.md" "specs/state.json")` pair) — never with `task_dir`.
- Lines 307-320: every `files_touched` entry failing `is_contained()` against that
  under-widened `file_scope_arr` is dropped, warned (`"dropping out-of-scope path '${f}' from
  phase commit — not in task ${task_number}'s declared file_scope"` — the exact wording the
  live incident's warning matches), and logged as a `scope excursion` issue.

A `files_touched` entry under the task's own directory (e.g.
`specs/{N}_{slug}/reports/01_....md`) is therefore staged by the line-201 seed and then removed
by the line-307 self-check whenever `file_scope` is declared, non-empty, and does not happen to
cover that directory — which is the ordinary case, since a task's `file_scope` is meant to
describe *source* territory, not its own already-implicit artifact directory.

### Why this is a propagation gap, not a new idea (confirmed against the doc)

`git-staging-scope.md`'s "Three Containment sites, not one" subsection (lines 342-398)
independently documents:

1. Site 1 (`orchestrate-cycle-postflight.sh` WORK (h), lines 1641-1646) already splices
   `"${task_dir_rel}/"` into `effective_file_scope_json` directly inline, with a comment citing
   "the lifecycle REQUIRES every task to write into its own resolved task directory... so that
   directory is treated as an unconditional in-scope prefix."
2. Site 3 (`git-commit-scoped.sh` V10, lines ~491-496) resolves `task_project_name` from the
   looked-up task entry, calls `task_lookup_dir()` (from `task-lookup-lib.sh`), and appends the
   result directly to `containment_scope_arr`, with a comment noting "the plan path itself needs
   no separate carve-out: it lives under the task's own directory, which this implicit member
   already admits."
3. Site 2 (`git-commit-phase.sh`) is named explicitly as the one that "never received it."

The doc's own words match the dispatch's framing verbatim — this is a documented, known gap
being closed, not a new design question.

**One correction to carry forward into the doc update**: the same subsection's "Site 3
therefore structurally subsumes site 2's own reach" paragraph is accurate only for the
*engine-written-state allowlist* gap (which V10 does close for every site-2 caller, since
`git-commit-phase.sh` always forwards `--task`). It does not hold for the task-directory member
specifically, because site 2's drop happens at the `stage_paths` construction stage — *before*
`git-commit-scoped.sh` (and hence V10) is ever invoked. A path site 2 has already excluded from
its own pathspec is never seen by V10 at all; V10 only tests paths it is actually handed. The
live incident is exactly this: the dropped report path never reached `git-commit-scoped.sh`'s
pathspec in the first place, so site 3's own task-directory carve-out had nothing to act on.
This nuance should be recorded alongside the new site-2 member so a future reader does not
re-derive the same over-broad "subsumption" belief from the existing prose.

### The `missing_key`-yet-dropped question — resolved

Candidates listed in the dispatch, tested against the actual write paths in this source store:

- **(a) Populated between review and commit by an earlier postflight's `--file-scope-add`
  union-merge — CONFIRMED as the mechanism.** `orchestrator-postflight.sh` Stage 7 (lines
  ~325-349): for `operation_type == research`, it forwards `.return-meta.json`'s
  `proposed_file_scope` (when non-empty) as `--file-scope-add`; for `operation_type == plan`, it
  forwards `plan-file-scope-harvest.sh`'s harvested union of every phase's "Files to modify"
  entries (also non-empty-gated). Both sources are **source-path-only by construction** — a
  research report's self-proposed scope and a plan's per-phase "Files to modify" field never
  name the task's own artifact directory, because nothing upstream is expected to declare it
  (it is meant to be implicit, per all three Containment sites' own design intent).
- **(b) Review and commit reading different state — true as a *consequence* of (a), not a
  separate defect.** Pre-dispatch review runs before the research dispatch that would populate
  `proposed_file_scope`; the phase commit this incident concerns runs during `implement`, after
  both research and (if applicable) plan postflights have already run their own
  `--file-scope-add` writes. The two reads are legitimately different points in the task's own
  lifecycle, not a race or a bug.
- **(c) The fail-open guard not covering the observed shape of "missing" — RULED OUT.** The
  guard at line 241 (`[ -n "$file_scope_json" ] && [ "$file_scope_json" != "null" ] &&
  [ "$file_scope_json" != "[]" ]`) correctly fails open on a genuinely absent/null/empty
  `file_scope`. By the time of the observed drop, `file_scope` was none of those — it was a
  real, non-empty array (populated by (a)) that simply did not happen to cover the task's own
  directory. The guard behaved exactly as designed; there is nothing to repair in it.

**Conclusion**: the `missing_key` report at pre-dispatch review and the later drop at phase
commit are both independently correct descriptions of the task's `file_scope` at two different,
legitimate moments in its lifecycle. No fail-open defect exists. The only fix required is the
missing task-directory member (dispatch scope item 1); nothing from this question needs a
separate code change, only the recorded explanation above (dispatch Acceptance criterion
"recorded, with whatever follow-on it implies either fixed here or filed" — the follow-on here
is "none"; this finding fully closes the question).

### The WHERE ruling — shared library vs. per-site splice

`engine-written-state-paths-lib.sh`'s header (lines 16-28) states the admission bar for that
shared allowlist verbatim: a candidate must be **both** (a) engine-written on behalf of
every/many tasks, not one task's own dispatch, **and** (b) never legitimately declarable in any
one task's own `file_scope`. Its own "Rejected candidates" list explicitly names **"any
task-owned `specs/{NNN}_*/` path"** and gives the reasoning: "this is exactly the territory
`file_scope` already exists to describe; a task's own directory belongs in that task's own
declared `file_scope`, not in a universal allowlist that bypasses the declaration mechanism
entirely."

This is dispositive, not merely a style preference: a per-task directory fails half (a) of the
library's own admission bar (it is authored by one task's own dispatch, not written by the
engine on behalf of every task) even though it does satisfy something like half (b) in spirit.
Sites 1 and 3 already implement the per-site splice shape precisely because of this — neither
hand-copies the task directory into the shared four-member literal array. **Ruling: site 2's new
member is a per-site splice inside `git-commit-phase.sh` itself, immediately alongside (not
inside) the existing engine-written-state-paths widening at lines ~258-270 — never added to
`engine-written-state-paths-lib.sh`.** No new shared-library member, no new shared-library
function signature change.

Practically, site 2 already has `task_dir` as a local bash variable in exactly the relative-path
form `file_scope_arr` entries use (`"specs/${padded_num}_${project_name}"`, set at line 193) —
simpler than sites 1 and 3, which must first resolve/derive it (site 1 strips `$PROJECT_ROOT` off
an absolute `$TASK_DIR`; site 3 calls `task_lookup_dir()` via `task-lookup-lib.sh`). The fix at
site 2 needs no new sourcing, no new helper call, and no archive-awareness concern (a phase
commit only ever fires against an active, in-dispatch task): `file_scope_arr+=("${task_dir}/")`,
placed inside the existing non-empty `file_scope_arr` guard (so the fail-open posture — a task
with no declared `file_scope` still skips the whole check — is unaffected), and placed before the
existing engine-written-state-paths splice is as reasonable as after; either ordering is
semantically identical since `is_contained()` only ever loops the full array.

### Test inventory (acceptance-fixture placement)

`test-git-commit-phase.sh` currently runs 14 numbered cases against a synthetic task `999`
(`project_name: "probe"`), ending at Case 14 ("fail-open... is unaffected by the engine-written-
state splice"). Relevant existing cases the new fixtures must not regress:

- **Case 7** (containment-port fixture): a `files_touched` path NOT contained in the declared
  `file_scope` is dropped with a warning; commit still lands minus that path. This is the
  "genuine excursion" behavior the hard constraints require to "survive intact, pinned by a
  test" — already pinned, and the new fixtures must not weaken it.
- **Case 8** / **Case 14**: fail-open on a missing `file_scope` — already pinned twice (once
  standalone, once re-confirmed against the engine-written-state splice specifically). The new
  task-directory splice must be added the same way the engine-written-state splice was: strictly
  inside the non-empty-`file_scope_arr` guard, so Cases 8/14's fail-open assertions keep passing
  unmodified.
- **Case 13**: a positive-admission-plus-paired-negative pattern (an engine-written path admits
  without a drop warning; Case 7's genuinely out-of-scope path in the *same* fixture still drops)
  is the established house style for proving a new admitted member without regressing the
  excursion guard. The new fixtures (own-task-directory report lands; sibling out-of-territory
  source path still drops) should follow this same paired-fixture shape, as new cases numbered
  from 15 onward.

## Decisions

1. **Fix location**: `git-commit-phase.sh`'s Phase-Commit Containment Self-Check (lines
   ~237-270), inside the existing non-empty `file_scope_arr` guard. One new array member,
   `"${task_dir}/"`, added via a per-site splice — not routed through
   `engine-written-state-paths-lib.sh`.
2. **WHERE ruling**: per-site splice, mirroring sites 1 and 3, on the documentary authority of
   `engine-written-state-paths-lib.sh`'s own explicit rejection of "any task-owned
   `specs/{NNN}_*/` path" as a shared-allowlist candidate. No shared-library signature change.
3. **Fail-open posture**: unchanged. The `missing_key`-yet-dropped question is resolved as a
   legitimate point-in-time difference (an earlier postflight's `--file-scope-add` write
   populating `file_scope` between pre-dispatch review and the later phase commit), not a
   fail-open defect. No code change beyond item 1 is implied by this question.
4. **Doc update**: `git-staging-scope.md`'s "Three Containment sites, not one" subsection gains
   site 2's new member (mirroring how project 425's record documented site 1's own addition),
   plus a correction narrowing the existing "Site 3... structurally subsumes site 2's own reach"
   claim to the engine-written-state-allowlist gap specifically — it does not cover the
   task-directory member, because site 2's drop happens upstream of `git-commit-scoped.sh`
   (and hence upstream of V10) entirely.
5. **Test placement**: new fixtures appended to `test-git-commit-phase.sh` as new numbered cases
   (15+), following the Case 13 paired-fixture style (own-directory report admitted without a
   drop warning; a sibling genuinely-out-of-territory source path in the same or an adjacent
   fixture still drops and still logs a `scope excursion` issue) plus one fixture reusing Case
   8/14's fail-open shape to confirm the new splice sits inside, not outside, the existing
   non-empty guard.

## Recommendations

1. Implement the single-line splice at `git-commit-phase.sh` lines ~258-270 (immediately
   alongside the existing engine-written-state-paths widening), using the already-local
   `task_dir` variable — no new sourcing or helper call needed.
2. Update `git-staging-scope.md`'s "Three Containment sites, not one" subsection: add a fourth
   enumerated fact recording site 2's new member and its relationship to sites 1 and 3 (mirrors
   project 425's precedent for site 1), and narrow the existing subsumption sentence as described
   in Decision 4 above.
3. Add new test cases to `test-git-commit-phase.sh`:
   a. A task's declared, non-empty `file_scope` that omits its own directory; a report path
      under that directory in `files_touched` lands in the commit with zero `scope excursion`
      issue records.
   b. In the same or a sibling fixture, a genuinely out-of-territory source path is still
      dropped, still warned, and still recorded (reusing/extending Case 7's assertion shape).
   c. A fail-open fixture (missing/empty/malformed `file_scope`) confirms the new splice never
      runs outside the non-empty guard (extends Cases 8/14).
4. No change to `orchestrator-postflight.sh`, `plan-file-scope-harvest.sh`, or the fail-open
   guard is recommended — the `missing_key`-yet-dropped question is fully explained by their
   existing, correct behavior.
5. Sequence after this task: tasks 430 and 486 (already dependent on this record in
   `specs/state.json`) should proceed only once this fix and doc update land, per the dispatch's
   own sequencing instruction.

## Risks & Mitigations

- **Risk**: adding `"${task_dir}/"` unconditionally could theoretically widen scope too far if
  `task_dir` were ever malformed (e.g. empty `project_name`). **Mitigation**: `task_dir` is
  constructed from `--task`/`--project`, both required arguments validated by `usage()` at
  script start (lines 180-184); an empty value is not reachable past argument parsing. No
  additional guard is needed beyond what already exists.
- **Risk**: placing the splice outside the non-empty `file_scope_arr` guard would silently grant
  every task an unconditional four-... now five-member scope even when it declared none,
  contradicting the fail-open posture. **Mitigation**: explicitly place the new line inside the
  existing `if [ "${#file_scope_arr[@]}" -gt 0 ]; then` block (mirroring exactly where the
  engine-written-state splice already sits), and pin this placement with the Case 8/14-style
  fail-open fixture in Recommendation 3c.
- **Risk**: a future reader re-trusting the un-narrowed "Site 3 structurally subsumes site 2"
  sentence in `git-staging-scope.md` could conclude site 2's self-check is redundant and safe to
  delete, reintroducing this exact defect once site 2's own drop (which happens before
  `git-commit-scoped.sh` is ever invoked) is misunderstood as something V10 would have caught.
  **Mitigation**: Decision 4 / Recommendation 2's doc narrowing closes this directly.

## Context Extension Recommendations

- **Topic**: none identified beyond what `git-staging-scope.md` itself will record once updated
  per Decision 4/Recommendation 2. No new standalone context file is warranted for a one-line
  fix whose rationale already has a documented home.

## Appendix

- Live symptom citation (external repository, not re-verifiable from this source store):
  `~/Projects/BimodalLogic/specs/878_lplus_ztime_decidability_paper_proof_repair/issues.jsonl`,
  `iss_1793906925617_Kqxs0T`.
- Key line ranges re-derived in this source store (subject to drift per the dispatch's own
  warning): `git-commit-phase.sh` lines 193, 196-231, 237-270, 307-320; `git-staging-scope.md`
  lines 294-411; `git-commit-scoped.sh` lines ~460-530; `orchestrate-cycle-postflight.sh` lines
  1625-1680; `engine-written-state-paths-lib.sh` lines 1-63; `orchestrator-postflight.sh` lines
  ~325-349; `test-git-commit-phase.sh` case headers through Case 14.
- `specs/state.json` dependency confirmation: task 430 `dependencies: [362,394,395,425,428,494]`;
  task 486 `dependencies: [430,446,484,494]`.
