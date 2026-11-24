# Implementation Plan: Task #690

- **Task**: 690 - Delete the orphaned milestone-ref-land.sh utility and its references
- **Status**: [IMPLEMENTING]
- **Effort**: 2 hours
- **Dependencies**: None
- **Research Inputs**: specs/690_milestone_ref_land_recreates_retired_ref/reports/01_milestone-ref-land-deletion-scope.md
- **Artifacts**: plans/01_milestone-ref-land-deletion.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: general
- **Lean Intent**: false

## Overview

`milestone-ref-land.sh` has no lifecycle caller in this source store: its retirement as a landing
mechanism is complete at the wiring level, and the two records that were assigned the
delete-or-reuse decision have both finished, leaving the file unowned. This plan deletes the
script, its dedicated suite, and every machine-read declaration of either, then re-points the two
context documents that still cite the script as the ref-plumbing idiom's worked implementation to
`review-stack-prepare.sh`, which already exercises the identical `git commit-tree` +
compare-and-swap `git update-ref` primitives at its review-ref build and restack sites. Done means:
no reference to the script or its suite survives anywhere under `agent-system/`, the ref-plumbing
pattern's TECHNIQUE content is retained intact behind a live implementation citation,
`generate-context-line-counts.sh --check` is clean, and a redeploy reports a clean verify with the
deployed copy gone.

### Research Integration

The research report confirms the dispatch's measured premise and closes the two decisions the
dispatch left open:

- The complete reference set is eight sites, one of which the dispatch's deletion list does not
  name: `scripts/tests/suite-classification.data`'s row for the deleted suite. A stale row there
  is `[INFO]`-only to `lint-unit-integration-boundary.sh` and would not fail verification, but it
  is the same class of dead reference the rest of this work removes, so Phase 1 removes it.
- `review-stack-prepare.sh` is the live, lifecycle-wired script implementing the idiom
  (`git commit-tree` at lines 1020, 1048, 1292; three-argument compare-and-swap `git update-ref`
  at 1049 and 1403) and is literally the use-site `ref-plumbing-landing.md`'s own "The Landing
  Mechanism" section already describes. The citation is therefore **re-pointed, not stripped** —
  the pattern keeps a runnable reference rather than becoming unanchored.
- `test-milestone-review-handoff.sh`'s reference is a **comment-only** sandbox-convention credit
  at line 8; nothing in that file sources, invokes, or functionally depends on the deleted suite.
  The record that owns handoff printing of the review stack, and its two siblings, are all
  `[COMPLETED]`, and none of the three touched that comment line. The dispatch's "declare the
  shared territory and order behind it" instruction is therefore discharged by recording that
  there is no live race — no dependency edge is added to an already-finished record.

### Premise Re-Validation (Carried-Figure Discipline)

Every figure this plan carries from the task description and the research report was re-derived at
plan-authoring time. Result, stated explicitly even where it only confirms the inputs unchanged:

| Carried claim | Source | Re-derivation at authoring time | Verdict |
|---|---|---|---|
| No lifecycle caller; references survive only in the script, its suite, the classification data row, one test comment, two manifest rows, two context docs | description + report | `grep -rn "milestone-ref-land" agent-system/` — 28 matching lines across exactly those 8 files, no hook, no other extension, no other script | CONFIRMED |
| Manifest rows at `manifest.json:289` and `:440`; data row at `suite-classification.data:155`; doc citations at `ref-plumbing-landing.md:9` and `:32`, `git-workflow-narrative.md:272`; comment at `test-milestone-review-handoff.sh:8` | report | Same grep; every line number matches today | CONFIRMED |
| Script 244 lines, suite 368 lines; `ref-plumbing-landing.md` 98 lines, `git-workflow-narrative.md` 324 lines | report | `wc -l` returns 244 / 368 / 98 / 324 | CONFIRMED |
| `index-entries.json` `line_count` for the two docs | report (implied) | Core `index-entries.json` carries 324 and 98 respectively, matching the files on disk | CONFIRMED |
| `review-stack-prepare.sh` implements the same idiom at the cited lines | report | `grep -n "commit-tree\|update-ref"` returns 1020, 1048, 1049, 1292, 1403 as cited | CONFIRMED |
| The suite builds `mktemp -d` fixtures with a deployed-shape `.claude/scripts/` tree and never touches live refs (description line 23) | description | Suite header documents `mktemp -d` workdirs with `trap EXIT` cleanup; `mktemp -d -p "$WORKDIR"` per case; fixture copies the script to `$d/.claude/scripts/` | CONFIRMED |
| The source store is the edit target (description line 55) | description | `.claude-extensions.json`'s `extensions.core.source_dir` resolves to `agent-system/extensions/core` in this repository | CONFIRMED |
| The consumer repository has a live ref writer that grep cannot find (description line 25) | description | **CARRIED-UNVERIFIED**, by design — that repository is out of this record's scope per the siting rule, and nothing in this plan depends on the claim's truth either way | CARRIED-UNVERIFIED |

One figure moved relative to a naive reading of the description: the description's deletion list
(steps 1-5) does not name `suite-classification.data`, so the reference set this plan acts on is
eight sites, not seven. That is an addition the research round found, not a correction to a
measured count.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No roadmap flag was passed on this dispatch, so no roadmap review or regeneration phase is
included. `specs/ROADMAP.md` was not consulted for sequencing.

## Goals & Non-Goals

**Goals**:
- Remove `milestone-ref-land.sh`, its dedicated suite, and all four machine-read declarations of
  them (two manifest rows, one suite-classification row, and — as a consequence — the deployed
  copy).
- Keep the ref-plumbing idiom documented: retain every technique section of
  `context/patterns/ref-plumbing-landing.md` verbatim and move only its implementation citation to
  `review-stack-prepare.sh`.
- Leave `context/standards/git-workflow-narrative.md`'s landing section stating the current design
  plainly, with no record-versioning language.
- Reduce `test-milestone-review-handoff.sh`'s reference to a self-contained statement of the
  sandbox convention that credits no file.
- Close with a clean `generate-context-line-counts.sh --check` and a clean redeploy verify.

**Non-Goals**:
- Repairing the script's first-landing / empty-oldvalue logic. The record's own analysis rules
  this out: fixing retirement-marker representation inside a script nothing calls buys nothing.
- Any `refs/heads/milestone/*` cleanup. The eight existing refs were already deleted by hand after
  proving each tip's tree byte-identical to a commit reachable on the relevant work branch and
  confirming no upstream; that tree-equality check (resolve the tip's tree, search the work
  branch's history for a commit with the identical tree) is the cheap durable test for whether
  such a ref carries unique content, and no ref work remains.
- Identifying or unwiring the consumer repository's live ref writer. That repository's own tree is
  the edit target, so the siting rule puts that task there. This record's "check before deleting"
  clause is satisfied for deleting from THIS source store: no caller exists in either tree, so
  nothing here depends on the file, and this deletion cannot regress that repository either way.
- Any mechanical staleness check for pattern-document implementation citations. A general
  cross-reference staleness detector is a larger, separately-scoped concern not warranted by one
  occurrence.
- Adding a dependency edge to the already-completed handoff-printing record.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| File deletions and manifest-row removals land in different commits, leaving a manifest-sync suite red on the intermediate state | M | M | Phase 1 declares `Commit Mode: atomic-batch`: the four paths are one objective, intermediate per-file states are expected red and are not committed |
| Deleting the script appears to strip the ref-plumbing pattern of its only runnable example | M | M | Re-point rather than strip: `review-stack-prepare.sh` exercises the identical primitives at verified line numbers and is already the use-site the pattern's own Landing Mechanism section describes |
| Rewriting `git-workflow-narrative.md:272` introduces draft-history phrasing ("no longer", "previously", "stays on disk") barred under `agent-system/**` | M | M | Phase 2 states the current design plainly in one sentence naming `review-stack-prepare.sh`; the phase's verification explicitly re-reads the new sentence for banned phrasing |
| A context-document edit leaves a dangling cross-reference that a prose diff read-through would not catch | M | L | Phase 2 declares tier `local` rather than `prose` specifically so the cross-reference and index-schema suites run over the edited paths |
| Redeploy runs before the document edits settle, leaving a stale deployed copy | L | L | Phase 3 depends on both earlier phases; the deploy is the last step, never inverted |
| The deployed `.claude/scripts/milestone-ref-land.sh` survives the redeploy as an orphan | M | L | Phase 3 verifies the deployed tree carries no reference and removes the orphan explicitly if the deploy's own orphan handling leaves it |
| The consumer repository's live writer remains unidentified | M | H | Out of scope by siting rule; recorded in Non-Goals rather than blocked on. This deletion cannot make it worse (that tree already lacks an invocation site) and cannot fix it |

## Decisions

- **The ref-plumbing document retains the TECHNIQUE and changes only its implementation
  citation.** The dispatch asked for this to be decided explicitly. The Idiom,
  Concurrency-Safety Property, Compare-And-Swap Obligation, and Prohibition sections are
  script-agnostic ("any script that needs to build or advance a ref...") and name no
  implementation outside the Audience line and one Landing Mechanism sentence. Those two
  sentences move to `review-stack-prepare.sh`; everything else is retained verbatim.
- **The two context documents are treated as part of the fix, not as cosmetic cleanup trailing
  it.** On the dispatch's own leading hypothesis for the consumer repository's unexplained ref
  advances — an agent read one of these documents, which still cite the script as an
  implementation, and ran it by hand — the documents ARE the invocation vector. Re-pointing them
  removes the only surviving instruction in this source store that names the script as something
  to run.
- **`suite-classification.data`'s row is removed in the same phase as the deletion**, though a
  stale row there is `[INFO]`-only and would not fail `lint-unit-integration-boundary.sh`'s exit
  verdict. The file's own header treats drift between the data and the discovered corpus as the
  thing to avoid.
- **No dependency edge is added for `test-milestone-review-handoff.sh`.** The record owning
  handoff printing of the review stack and its two siblings are all complete and none touched
  the comment line this plan edits, so declaring the shared territory is the whole of the
  obligation; there is no live race to order behind.
- **`index-entries.json` is declared in Phase 2 and reconciled in Phase 3.** Editing an indexed
  `context/**` file moves that file's `line_count`, which `check-extension-docs.sh` Rule R checks
  and the deploy regenerates. That check is not commit-blocking in this repository — no
  `pre-commit` hook is installed, verified at authoring time — so the coupled-generated-surface
  obligation permits declaring the derived path in the phase that moves the quantity while
  reconciling it in a later phase.

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2 | 1 |
| 3 | 3 | 1, 2 |

Phases within the same wave can execute in parallel.

### Phase 1: Remove the script, its suite, and its machine-read declarations [COMPLETED]

**Goal**: Eliminate the executable surface and every declaration a script or lint reads, in one
atomic batch so no intermediate state leaves the manifest describing a file that is gone.

**Tasks**:
- [x] Re-run `grep -rn "milestone-ref-land" agent-system/` and record the reference set before
      touching anything; confirm it still matches the eight sites this plan's Premise
      Re-Validation table names. *(completed: re-grep before deletion returned the same 8
      sites: script, suite, manifest x2 rows, suite-classification.data, 1 test comment, 2
      context docs)*
- [x] Delete `agent-system/extensions/core/scripts/milestone-ref-land.sh`. *(completed)*
- [x] Delete `agent-system/extensions/core/scripts/tests/test-milestone-ref-land.sh`. *(completed)*
- [x] Remove the `"milestone-ref-land.sh",` entry from `manifest.json`'s scripts array and the
      `"tests/test-milestone-ref-land.sh",` entry from its tests array; confirm by grep that zero
      occurrences of either string remain in the file and that the JSON still parses (`jq . `).
      *(completed: both rows removed, `jq -e .` exits 0)*
- [x] Remove the `test-milestone-ref-land.sh` row from
      `agent-system/extensions/core/scripts/tests/suite-classification.data`, preserving the
      file's tab-separated column shape for every surviving row. *(completed: removed via
      `sed` on the exact tab-separated line; surrounding rows unchanged)*
- [x] Confirm the deletion orphans no exclusive library dependency: the script sourced only
      `lib/common.sh` and `deploy-root-guard.sh`, both shared by many other scripts.
      *(completed: 79 other scripts under scripts/*.sh still reference deploy-root-guard.sh or
      lib/common.sh)*

**Timing**: 0.5 hours

**Depends on**: none

**Verification Tier**: interface

**Commit Mode**: atomic-batch

**Scope Hypothesis**: the hypothesis is that this phase's four paths are the complete set of
machine-read declarations of the script and its suite, and that removing them leaves exactly
three surviving textual references (the two context documents and one test comment, all Phase 2's
targets). This is carried from
`reports/01_milestone-ref-land-deletion-scope.md`'s reference inventory and was re-derived at
plan-authoring time by `grep -rn "milestone-ref-land" agent-system/`. Confirm at implementation
time by re-running that same grep immediately before and immediately after the batch and
comparing the two outputs against this prediction.

**Tier Justification**: `bash agent-system/extensions/core/scripts/verify-touched.sh`, run over
this phase's four declared `Files to modify` paths, is the covering check — it resolves them to
the manifest-inventory and suite-classification consumers that are the enumerated direct
dependents of the removed declaration, and runs that narrowed pass itself, which the cheaper
`local` tier's single-module build would not reach.

**Files to modify**:
- `agent-system/extensions/core/scripts/milestone-ref-land.sh` - deleted; 244 lines, confirmed present at plan-authoring time. If absent when the phase runs, record it as already removed and continue with the remaining three paths rather than treating the phase as blocked.
- `agent-system/extensions/core/scripts/tests/test-milestone-ref-land.sh` - deleted; 368 lines, confirmed present at plan-authoring time. Same fallback as above if absent.
- `agent-system/extensions/core/manifest.json` - remove the script-array and tests-array rows naming the two deleted files
- `agent-system/extensions/core/scripts/tests/suite-classification.data` - remove the classification row for the deleted suite

**Verification**:
- `grep -rn "milestone-ref-land" agent-system/` returns matches in exactly three files — the two
  context documents and `test-milestone-review-handoff.sh` — and nothing else.
- `jq -e . agent-system/extensions/core/manifest.json >/dev/null` exits 0.
- `bash agent-system/extensions/core/scripts/verify-touched.sh` over this phase's four paths exits
  0; the exit status is checked directly, never inferred from a diff of captured output.

---

### Phase 2: Re-point the documentation and the sandbox-convention credit [COMPLETED]

**Goal**: Leave no instruction anywhere in this source store naming the deleted script as
something to run, while keeping the ref-plumbing technique fully documented behind a live
implementation.

**Tasks**:
- [x] `context/patterns/ref-plumbing-landing.md`, Audience line: replace the named worked
      implementation with `agent-system/extensions/core/scripts/review-stack-prepare.sh`.
      *(completed)*
- [x] `context/patterns/ref-plumbing-landing.md`, "The Landing Mechanism" section: replace the
      sentence citing the deleted script with one naming `scripts/review-stack-prepare.sh` as
      where the idiom is exercised today (it builds and restacks the review ref with
      `git commit-tree` and three-argument compare-and-swap `git update-ref`). Confirm the Idiom,
      Concurrency-Safety Property, Compare-And-Swap Obligation, and Prohibition sections are
      byte-unchanged afterward. *(completed: `git diff` confirms those four sections are
      untouched)*
- [x] `context/standards/git-workflow-narrative.md`, "Landing Is a Verification" section: replace
      the sentence that describes the script as retired-but-on-disk with one stating the current
      design plainly — that the idiom's compare-and-swap property is exercised by
      `scripts/review-stack-prepare.sh`, which builds and restacks the review ref using the same
      primitives. *(completed)*
- [x] `scripts/tests/test-milestone-review-handoff.sh`, header comment: reword to describe the
      sandbox convention on its own terms (`deploy-root-guard.sh`'s default structural check
      requires the script's own directory to end in `/.claude` or `/.opencode`), crediting no
      file. Comment-only; no behavior change. *(completed: `git diff` shows a single comment-only
      hunk)*
- [x] Re-read all four edited regions for the two prohibited classes under `agent-system/**`: no
      task-number references, and no record-versioning phrasing ("no longer", "previously",
      "used to", "stays on disk", "retired as"). *(completed: none found)*

**Timing**: 0.75 hours

**Depends on**: 1

**Verification Tier**: local

**Scope Hypothesis**: the hypothesis is that exactly four edit sites remain — the Audience line
and the Landing Mechanism sentence of `ref-plumbing-landing.md`, one sentence in
`git-workflow-narrative.md`'s landing section, and one header comment line in
`test-milestone-review-handoff.sh` — and that the two documents' current `line_count` values in
`agent-system/extensions/core/index-entries.json` are 324 and 98. Both figures are carried from
`reports/01_milestone-ref-land-deletion-scope.md` and were re-derived at plan-authoring time
(`grep -rn`, `wc -l`, and a read of the two index entries). Confirm at implementation time by
re-reading each cited region before editing it, and by reading the two `line_count` fields before
Phase 3 regenerates them.

**Tier Justification**: `bash agent-system/extensions/core/scripts/verify-touched.sh`, run over
this phase's declared `Files to modify` paths, is the covering check — it runs the
context-reachability and index-schema passes that a broken `context/**` cross-reference would
trip, which is precisely the blind spot the cheaper `prose` tier's diff read-through leaves open
for an indexed document edit.

**Files to modify**:
- `agent-system/extensions/core/context/patterns/ref-plumbing-landing.md` - re-point the Audience line and the Landing Mechanism sentence to `review-stack-prepare.sh`; retain every technique section verbatim. Confirmed present at plan-authoring time (98 lines).
- `agent-system/extensions/core/context/standards/git-workflow-narrative.md` - replace the landing-section sentence describing the deleted script with a plain statement of the current design. Confirmed present at plan-authoring time (324 lines).
- `agent-system/extensions/core/scripts/tests/test-milestone-review-handoff.sh` - reword the header comment to credit no file. Confirmed present at plan-authoring time.
- `agent-system/extensions/core/index-entries.json` - coupled generated surface: the two context documents' `line_count` fields derive from the prose this phase edits. Declared here per the coupled-generated-surface obligation; reconciled in Phase 3 because the detecting check is advisory, not commit-blocking (no `pre-commit` hook is installed in this repository, verified at plan-authoring time).

**Verification**:
- `grep -rn "milestone-ref-land" agent-system/` returns nothing.
- `git diff` on `ref-plumbing-landing.md` shows changed hunks only in the Audience line and the
  Landing Mechanism sentence; the Idiom, Concurrency-Safety Property, Compare-And-Swap
  Obligation, and Prohibition sections are untouched.
- `git diff` on `test-milestone-review-handoff.sh` shows a single changed line, entirely inside a
  comment.
- `bash agent-system/extensions/core/scripts/verify-touched.sh` over this phase's declared paths
  exits 0; the exit status is checked directly, never inferred from a diff of captured output.
- No task-number reference and no record-versioning phrasing appears in any edited region.

---

### Phase 3: Reconcile line counts, redeploy, and close verification [NOT STARTED]

**Goal**: Bring the derived line counts back in sync, regenerate the deployed tree so it carries
no trace of the deleted script, and discharge this task's scoped verification obligation.

**Tasks**:
- [ ] Run `bash agent-system/extensions/core/scripts/generate-context-line-counts.sh --check`;
      on reported drift run the same script with `--write`, then re-run `--check` and confirm it
      exits 0.
- [ ] Redeploy using the bounded-wait idiom: `timeout 540 bash
      agent-system/extensions/core/scripts/deploy-headless.sh` with the Bash tool timeout set to
      600000. Capture the deploy's own verify report.
- [ ] Confirm the deployed tree carries no trace of the deleted script:
      `grep -rn "milestone-ref-land" .claude/` returns nothing and
      `.claude/scripts/milestone-ref-land.sh` is absent. If the deploy's orphan handling leaves
      the file behind, remove the orphan explicitly and re-check.
- [ ] Run the scoped touched-path check over every path this task touched:
      `bash agent-system/extensions/core/scripts/verify-touched.sh` with this task's declared
      paths, checking its exit status directly. Under `/orchestrate`, the complete gate set is
      deferred to the orchestration close (the once-per-invocation batch gate stage) and is not
      independently invoked here; record that deferral in this phase's verification notes. In a
      standalone, non-orchestrated run with no orchestration close to defer to, run
      `bash .claude/scripts/verify-deploy.sh` directly instead.

**Timing**: 0.75 hours

**Depends on**: 1, 2

**Verification Tier**: full

**Scope Hypothesis**: the hypothesis is that exactly two `line_count` fields move — the entries
for `patterns/ref-plumbing-landing.md` and `standards/git-workflow-narrative.md` in
`agent-system/extensions/core/index-entries.json`, carried from this plan's own Phase 2
re-derivation of their current values (98 and 324). Confirm at implementation time by reading
`generate-context-line-counts.sh --check`'s drift report before running `--write` and checking
that it names only those two entries; a third named entry means some other indexed file moved and
needs accounting before the write.

**Files to modify**:
- `agent-system/extensions/core/index-entries.json` - `line_count` reconciled for the two context documents edited in Phase 2
- `__WHOLE_TREE__` - this phase invokes whole-tree regeneration via the deploy script, an implicit scope claim over the entire deployed tree

**Verification**:
- `bash agent-system/extensions/core/scripts/generate-context-line-counts.sh --check` exits 0.
- The deploy reports a clean verify, and its exit status is checked directly rather than inferred
  from its output text.
- `grep -rn "milestone-ref-land" .claude/` returns nothing, and
  `.claude/scripts/milestone-ref-land.sh` does not exist.
- `grep -rn "milestone-ref-land" agent-system/` still returns nothing.
- `bash agent-system/extensions/core/scripts/verify-touched.sh` over this task's touched paths
  exits 0, with the complete gate set deferred to the orchestration close per the batch gate
  stage; the deferral is recorded in this phase's notes rather than left implicit.

## Testing & Validation

- [ ] `grep -rn "milestone-ref-land" agent-system/` finds no remaining reference to the script or
      its suite — the record's own primary "verify by" criterion.
- [ ] `grep -rn "milestone-ref-land" .claude/` likewise finds nothing after the redeploy.
- [ ] `jq -e . agent-system/extensions/core/manifest.json` parses, with no row for either deleted
      file.
- [ ] `suite-classification.data` has no row for the deleted suite and preserves its
      tab-separated shape for every surviving row.
- [ ] Neither context document cites the deleted script as an implementation; the ref-plumbing
      pattern's technique sections are byte-unchanged.
- [ ] `test-milestone-review-handoff.sh` is green and its only change is one comment line.
- [ ] `bash agent-system/extensions/core/scripts/generate-context-line-counts.sh --check` exits 0.
- [ ] The redeploy reports a clean verify.
- [ ] No task-number reference and no record-versioning phrasing was introduced under
      `agent-system/**`.

## Artifacts & Outputs

- `agent-system/extensions/core/scripts/milestone-ref-land.sh` — removed
- `agent-system/extensions/core/scripts/tests/test-milestone-ref-land.sh` — removed
- `agent-system/extensions/core/manifest.json` — two rows removed
- `agent-system/extensions/core/scripts/tests/suite-classification.data` — one row removed
- `agent-system/extensions/core/context/patterns/ref-plumbing-landing.md` — implementation
  citation re-pointed, technique retained
- `agent-system/extensions/core/context/standards/git-workflow-narrative.md` — landing-section
  sentence restated against the current design
- `agent-system/extensions/core/scripts/tests/test-milestone-review-handoff.sh` — header comment
  self-contained
- `agent-system/extensions/core/index-entries.json` — `line_count` reconciled for two entries
- Regenerated `.claude/` deployed tree with no trace of the deleted script
- `specs/690_milestone_ref_land_recreates_retired_ref/summaries/01_*-summary.md` — implementation
  summary

## Rollback/Contingency

Each phase is a scoped commit, so the ordinary contingency is `git revert` of the offending phase
commit — no working-tree discard is involved and no snapshot is needed. Phase 1 is an
`atomic-batch` objective precisely so that reverting it restores a self-consistent manifest and
corpus in one step.

If a genuine rollback of uncommitted work becomes necessary mid-phase, take the snapshot first
using the invocation shape named in `context/contracts/recovery.md`'s rollback rung (including its
out-of-scope override flag for a deliberate whole-tree case), then perform the revert; do not run
a destructive git operation on a dirty tree without it.

If the redeploy in Phase 3 fails verification, the source-store edits from Phases 1 and 2 remain
valid and committed; re-run the deploy rather than reverting the deletions, and if the deploy
cannot be made clean, record the failure and leave the task `[PARTIAL]` at Phase 3 with the
source store already consistent.
