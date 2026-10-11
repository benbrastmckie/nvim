# Implementation Plan: Task #372

- **Task**: 372 - Add the conclusion stage missing report block and name its roadmap-generator caller
- **Status**: [IMPLEMENTING]
- **Effort**: 1.75 hours
- **Dependencies**: None (parallel-eligible with task 371; no dependencies[] edge)
- **Research Inputs**: specs/372_conclusion_stage_report_block_and_caller_split/reports/01_conclusion-report-block-caller-split.md
- **Artifacts**: plans/01_conclusion-report-block-caller-split.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

The task as described carried two gaps; only one survives contact with the current repository.
GAP 1 (the conclusion stage's Step 6 pointing at a report block that does not exist) is already
closed: the `### Conclusion` block is present in `orchestrate-batch-results-template.md` and the
source-store and deployed copies are byte-identical. GAP 2 is real: the roadmap generator's
caller contract does not name `/orchestrate`'s conclusion stage as a caller of `--regenerate`,
and the `/todo`//`review` unwired-mode question is recorded only as an observation, never as a
decision. This plan therefore reduces to one verification phase plus three small, textually
adjacent contract edits, then a redeploy and the full gate set. All edits are documentation and
contract prose under `agent-system/extensions/core/**`; nothing executable changes.

### Research Integration

The research report's four load-bearing findings drive the phase structure:

1. GAP 1 is closed and must be verified, not re-authored (its Decision 1).
2. GAP 2(a) is factual and uncontroversial: add the conclusion stage as a named caller of
   `--regenerate` (its Decision 2).
3. `roadmap-update.md`'s own `## No Live Caller Yet` section is **currently false** independently
   of this task, because the conclusion stage's Step 5 already calls `--regenerate` in
   production. Correcting it is not scope creep: adding GAP 2(a)'s sentence without it would
   leave two adjacent sections of the same file contradicting each other (its Decision 3).
4. GAP 2(b) is closed by a recorded ruling, not by wiring — per the task description's own
   "do not wire a mode into a command merely to make a table symmetric" (its Decision 4).

Two additions this plan makes beyond the report, both established by plan-time reads rather than
carried from it:

- **A fourth stale caller claim the report did not name.** `docs/reference/utility-scripts-inventory.md`
  repeats `**No live caller yet** — neither /todo nor /review invokes it` for
  `roadmap-integration.sh`. That sentence becomes false the moment the caller split names the
  conclusion stage, so the inventory gets the same one-phrase correction. The report's declared
  three-file scope is widened to four for this reason.
- **A territory hazard the report did not have access to.** The dispatch's own Territory block
  shows sibling task 373, dispatched this same cycle on this same working tree, declaring
  `conclusion-stage.md`, `orchestrate-batch-results-template.md` and
  `docs/reference/utility-scripts-inventory.md` in its file_scope — three of this plan's four
  files. Every phase that touches those files carries a re-read-immediately-before-edit and
  own-hunks-only staging requirement.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No `roadmap_path` was provided in the delegation context, so no roadmap consultation was
performed and no roadmap phases are added. (`specs/ROADMAP.md` exists in this repository but was
not supplied as an input to this dispatch.)

## Goals & Non-Goals

**Goals**:
- Verify, with reproduced evidence, that the conclusion report block exists and Step 6's pointer
  resolves to it — satisfying that acceptance criterion without re-authoring existing content.
- Name `/orchestrate`'s conclusion stage (Move 5, Step 5) as a live caller of the roadmap
  generator's `--regenerate` mode in `context/patterns/roadmap-update.md`.
- Correct every stale "no live caller" claim that the above makes false, in both the caller
  contract and the utility-scripts inventory.
- Close the `/todo`//`review` unwired-mode question with an explicit recorded ruling (deliberately
  left open, not wired).
- Discharge `conclusion-stage.md`'s `## Two Flags For the User, Not Silent Edits` section and
  remove the now-vestigial carry-forward machinery in Step 5, Step 6, and the results template's
  `{roadmap_flags}` placeholder.
- Redeploy the source store and pass the full gate set.

**Non-Goals**:
- No change to `agent-system/extensions/core/scripts/roadmap-integration.sh` (task 371's file).
- No wiring of `/todo` to `--prune` or `/review` to `--regenerate`; the ruling records the gap as
  deliberately open.
- No change to the conclusion stage's three-channel derivation contract, its approval-ledger
  mechanics, or its tool-restriction tables beyond naming the caller.
- No edit to `agent-system/extensions/core/scripts/git-commit-scoped.sh`.
- No re-authoring or restructuring of the existing `### Conclusion` template block beyond the
  single `**Roadmap**` line the discharged flags make stale.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Sibling task 373 edits `conclusion-stage.md`, the results template, or the utility-scripts inventory concurrently on this shared tree | H | M | Re-read each file immediately before editing it (Phases 2-4 each state this); stage only this task's own hunks with an explicit file list, never a directory or glob add; never run `git-snapshot.sh` in its reverting default mode; treat an unexpected gate failure in a file outside this plan's four-file scope as possibly a sibling's in-flight edit and report rather than "fix" it |
| Task 371 lands first and changes which generator modes exist, making the new caller sentence wrong | M | L | Phase 1 re-reads `roadmap-integration.sh`'s header and `--help` mode list and confirms `--print`/`--regenerate`/`--prune` still mean what the caller contract asserts, before any edit to that contract |
| Removing `{roadmap_flags}` reads as silently dropping observability the stage's design valued | M | L | The placeholder referred only to these two specific, now-discharged flags — never a generic future-flag slot. Phase 3 states this in the edit's own rationale; a genuinely new future flag gets its own contract amendment |
| A future reader wonders why GAP 1's acceptance criterion is satisfied with no diff in this task's commits | L | M | Phase 1 records the verification evidence (the block's presence, the source/deployed parity, and commit `4e70e2239` as the origin) in the implementation summary, so the absence of a diff is explained rather than looking like an omission |
| Discharging the `## Two Flags` section breaks an inbound cross-reference | L | L | Grepped at plan time: the only references to that section name are inside `conclusion-stage.md` itself (its own heading and Step 5's back-pointer), both of which Phase 3 edits in the same pass. Phase 3 re-runs that grep before editing |
| Record-versioning language creeps in while rewriting sections that describe resolved gaps | M | M | Both Phase 2 and Phase 3 state current design only — no "previously", "no longer", "used to be flagged", or supersession framing — per `rules/no-record-versioning-in-deliverables.md`; Gate 3's doc-lint and the Phase 4 full run are the mechanical backstop |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2 | 1 |
| 3 | 3 | 2 |
| 4 | 4 | 3 |

Phases within the same wave can execute in parallel. This plan is fully sequential: Phase 2's
edits depend on Phase 1's confirmation of the generator's mode set, and Phase 3's cross-reference
points at the section Phase 2 writes.

### Phase 1: Verify GAP 1 Closed and Confirm the Generator's Mode Set [COMPLETED]

**Goal**: Establish, with reproduced evidence, that the conclusion report block already exists
and that the generator's mode vocabulary is still what the caller contract asserts — so the
remaining phases edit from confirmed facts rather than carried claims. No file is modified.

**Tasks**:
- [x] Confirm the `### Conclusion` subsection exists in
      `agent-system/extensions/core/context/patterns/orchestrate-batch-results-template.md`:
      `grep -n '^### Conclusion' agent-system/extensions/core/context/patterns/orchestrate-batch-results-template.md`
      *(completed: found at line 161, exit 0, exactly one match)*
- [x] Confirm that block covers all five items `conclusion-stage.md`'s Step 6 enumerates (wins
      summary; per-channel outcome with citations; unknown-class tally; zero-contribution
      dispatch list; the roadmap line), by reading the block and Step 6 side by side
      *(completed: all five present — Wins, Channel (a)/(b)/(c), Unknown-class tally,
      Zero-contribution dispatches, Roadmap line)*
- [x] Confirm Step 6's pointer text resolves to that block (the pointer names
      `context/patterns/orchestrate-batch-results-template.md`'s conclusion report block; the
      block is present under that exact path) *(completed)*
- [x] Confirm source-store and deployed parity for all four scoped files:
      `for f in context/patterns/orchestrate-batch-results-template.md context/patterns/roadmap-update.md context/contracts/conclusion-stage.md docs/reference/utility-scripts-inventory.md; do diff -q "agent-system/extensions/core/$f" ".claude/$f"; done`
      *(completed: all four diff -q exit 0, no output)*
- [x] Re-read `agent-system/extensions/core/scripts/roadmap-integration.sh`'s header comment and
      its `--help` mode list; confirm `--print` / `--regenerate` / `--prune` still mean what
      `roadmap-update.md`'s Responsibility Split and Flags sections assert. If task 371 has
      landed and changed the mode set, STOP and report before editing the caller contract
      *(completed: mode set unchanged, task 371 has not altered it)*
- [x] Re-confirm GAP 2(b) is still open: `grep -rn 'roadmap-integration' agent-system/extensions/core/skills/skill-todo/SKILL.md agent-system/extensions/core/commands/review.md` returns nothing
      *(completed: no matches, exit 1, confirmed still open)*
- [x] Record the evidence (command outputs, and commit `4e70e2239` as the origin of the template
      block) for inclusion in the implementation summary
      *(completed: commit 4e70e2239 "task 273 phase 8: architecture and command documentation"
      confirmed as origin; full evidence recorded in progress/phase-1-progress.json)*

**Timing**: 0.25 hours

**Depends on**: none

**Verification Tier**: prose

**Scope Hypothesis**: This phase asserts four claims carried from the research report: that the
`### Conclusion` block exists and covers Step 6's five items; that source and deployed copies are
byte-identical; that commit `4e70e2239` added the block; and that `/todo`//`review` remain
unwired. The first two and the fourth were re-derived at plan-authoring time and held; the
commit attribution was confirmed to exist by `git log --oneline -1 4e70e2239` but its content
attribution is carried from the report. This phase's whole purpose is to re-run all four checks
in the implementation dispatch and confirm them against the tree as it stands then, since a
sibling may have moved the tree in between.

**Tier Justification**: No file is written in this phase, so no suite can regress; the phase's
own covering check is the set of `grep`/`diff`/`git log` commands enumerated in its task list,
whose exit statuses are the verification.

**Files to modify**:
- none planned (verification-only phase)

**Verification**:
- `grep -n '^### Conclusion' agent-system/extensions/core/context/patterns/orchestrate-batch-results-template.md` exits 0 with exactly one match
- All four `diff -q` invocations exit 0 (no output)
- `roadmap-integration.sh`'s `--help` lists `--print`, `--regenerate`, and `--prune`
- The `grep -rn 'roadmap-integration'` over `skill-todo/SKILL.md` and `commands/review.md` exits 1 (no matches), confirming GAP 2(b) still open
- Evidence captured in the task's progress notes for the summary

---

### Phase 2: Fix the Caller Contract and the Inventory's Stale Caller Claim [COMPLETED]

**Goal**: Name the conclusion stage as a caller of `--regenerate`, correct the two now-false "no
live caller" claims this creates, and close the `/todo`//`review` wiring question with an
explicit ruling.

**Tasks**:
- [x] Re-read `agent-system/extensions/core/context/patterns/roadmap-update.md` immediately
      before editing (sibling-concurrency requirement) *(completed)*
- [x] In its `## Responsibility Split` section, extend the `--regenerate` bullet (or add an
      adjacent bullet) naming `/orchestrate`'s conclusion stage (Move 5, Step 5) as a caller
      alongside `/review`, cross-referencing `context/contracts/conclusion-stage.md`'s Step 5
      *(completed)*
- [x] Rewrite the `## No Live Caller Yet` section — heading and body — to state the actual split
      as current design: `--regenerate` has exactly one live caller today (the conclusion stage);
      `--prune` has none, and the safe interim invocation for `--prune` is `--dry-run` by hand.
      Choose a heading that describes the current state rather than the old claim
      *(completed: renamed to "## Live Callers")*
- [x] In that same section, record the ruling closing GAP 2(b) explicitly: wiring `/todo` to
      `--prune` and `/review` to `--regenerate` is acknowledged and deliberately left open; a
      mode is not wired into a command to make a table symmetric; a follow-up may be filed via
      `/task` or `/spawn` if and when a concrete operational need arises. State it as a decision,
      not an observation — the acceptance criterion requires a *recorded ruling*
      *(completed: added a "**Ruling**:" paragraph)*
- [x] Re-read `agent-system/extensions/core/docs/reference/utility-scripts-inventory.md`
      immediately before editing *(completed)*
- [x] Correct that file's `roadmap-integration.sh` entry: replace the `**No live caller yet** —
      neither /todo nor /review invokes it` phrase with the accurate split (the conclusion stage
      calls `--regenerate`; `--prune` has no caller and `--dry-run` by hand is the safe interim
      invocation), keeping the entry's existing one-line-per-script house style *(completed)*
- [x] Verify no record-versioning language was introduced (no "previously", "no longer", "used
      to", "formerly", supersession framing) — current design only
      *(completed: grep clean of new occurrences; one pre-existing unrelated hit on a different
      script's entry, not introduced by this edit)*
- [x] Verify no task-number references were introduced in either file
      (`rules/no-task-references-in-deliverables.md`) *(completed: grep returns nothing)*
- [x] Stage and commit exactly these two files by explicit path list via
      `.claude/scripts/git-commit-scoped.sh` — never a directory or glob add
      *(completed: also included `agent-system/extensions/core/index-entries.json` — a
      mechanical one-line line_count correction for the `roadmap-update.md` entry, produced by
      the sanctioned `generate-context-line-counts.sh --write` tool as a direct side effect of
      this phase's own edit growing that file from 112 to 122 lines; see Phase 2's Deviation
      note below)*

**Timing**: 0.5 hours

**Depends on**: 1

**Verification Tier**: prose

**Scope Hypothesis**: This phase asserts the whole caller-claim correction is confined to two
files and that `roadmap-update.md`'s stale claims live in exactly two sections (`## Responsibility
Split` and `## No Live Caller Yet`). Both were established by plan-time reads of the current file
plus a repository-wide `grep -rn 'No Live Caller Yet\|roadmap-update.md'` over
`agent-system/**`, which surfaced exactly these two files plus three read-only cross-references
(`roadmap-integration.sh`'s header pointer, `postflight-tool-restrictions.md`'s prohibition, and
`roadmap-format.md`'s Related entry) that need no change. Confirm at implementation time by
re-running that grep and checking each hit before deciding it needs no edit.

**Tier Justification**: Both files are pure-guidance markdown with no executable surface, so
`suite_selection_select` returns `__FULL_SWEEP__` for them and no shell suite covers them; the
honest covering check is `bash .claude/scripts/verify-deploy.sh --only-gate 3,4` (doc-lint and
task-reference lint) plus a diff read-through confirming every changed hunk is prose.

**Files to modify**:
- `agent-system/extensions/core/context/patterns/roadmap-update.md` - name the conclusion stage as a `--regenerate` caller; rewrite the stale no-live-caller section to the actual split; record the GAP 2(b) ruling
- `agent-system/extensions/core/docs/reference/utility-scripts-inventory.md` - correct the `roadmap-integration.sh` entry's now-false "no live caller yet" phrase

**Verification**:
- `grep -n 'conclusion' agent-system/extensions/core/context/patterns/roadmap-update.md` shows the new caller sentence in the Responsibility Split section
- `grep -n 'No Live Caller Yet' agent-system/extensions/core/context/patterns/roadmap-update.md` returns nothing (heading replaced with a current-state one)
- `grep -n 'No live caller yet' agent-system/extensions/core/docs/reference/utility-scripts-inventory.md` returns nothing
- The ruling text in `roadmap-update.md` reads as a decision (names the choice and its rationale), not as a bare observation of the gap
- `bash .claude/scripts/verify-deploy.sh --only-gate 3,4` exits 0
- Diff read-through confirms every changed hunk is prose inside a markdown body
- `git status --short` and `git diff --staged` reviewed before commit; only these two files staged

---

### Phase 3: Discharge the Two Flags and Remove the Vestigial Carry-Forward Machinery [COMPLETED]

**Goal**: Replace `conclusion-stage.md`'s `## Two Flags For the User, Not Silent Edits` section
with a current-state pointer, remove the Step 5 carry-forward instruction and the Step 6 report
item it feeds, and simplify the results template's `**Roadmap**` line accordingly.

**Tasks**:
- [x] Re-read `agent-system/extensions/core/context/contracts/conclusion-stage.md` immediately
      before editing (sibling 373 declares this file in its own file_scope) *(completed)*
- [x] Re-run `grep -rn 'Two Flags' agent-system/` to confirm the only references remain inside
      this file (its own heading and Step 5's back-pointer); if a new inbound reference appeared,
      handle it before editing *(completed: only the two expected in-file references found)*
- [x] Replace the `## Two Flags For the User, Not Silent Edits` section with a short current-state
      subsection: the roadmap generator's caller split — including this stage as a `--regenerate`
      caller — is documented in `context/patterns/roadmap-update.md`, and the `/todo`//`review`
      wiring question is closed by the ruling recorded in that same file. Write it as the current
      design, with no narration of what used to be flagged
      (`rules/no-record-versioning-in-deliverables.md`)
      *(completed: replaced with "## Roadmap Generator Caller Status")*
- [x] In Step 5, remove the "Carry forward, into Step 6's report, the two flags this stage's
      design surfaced ..." instruction. Leave the `--regenerate` invocation, the `--prune`
      out-of-scope note, and the commit block untouched *(completed)*
- [x] In Step 6, remove "and the two roadmap flags carried from Step 5" from the enumerated
      report contents, leaving the other four items and the template pointer intact *(completed)*
- [x] Re-read `agent-system/extensions/core/context/patterns/orchestrate-batch-results-template.md`
      immediately before editing (also in sibling 373's file_scope) *(completed)*
- [x] In its `### Conclusion` block, simplify the `**Roadmap**` line to state only that
      `specs/ROADMAP.md` was regenerated — dropping the `{roadmap_flags}` placeholder and its
      explanatory clause. Make no other change to the block: the five Step 6 items it already
      covers stay as they are, and the subsection count in the file's header stays accurate
      because no subsection is added or removed
      *(completed: the header's "eleven ###-level subsections" count was already stale before
      this edit — 12 actual headings predate this phase's change, confirmed via git diff showing
      no heading added/removed here — pre-existing and out of this task's scope to correct)*
- [x] Confirm Step 6's five enumerated items and the template block still correspond one-to-one
      after both edits
      *(completed: Step 6 now enumerates four items — wins, channel outcomes, unknown-class
      tally, zero-contribution dispatches — all present in the template block; the template's
      Roadmap line is a separate, un-enumerated line in both places, consistently dropped from
      Step 6's list on both sides)*
- [x] Verify no record-versioning language and no task-number references were introduced
      *(completed: both greps return nothing)*
- [x] Stage and commit exactly these two files by explicit path list via
      `.claude/scripts/git-commit-scoped.sh`
      *(completed: also included `agent-system/extensions/core/index-entries.json`'s two
      corrected line_count entries as a separate follow-up commit, same pattern as Phase 2 — see
      Phase 3's Deviation note)*

**Timing**: 0.5 hours

**Depends on**: 2

**Verification Tier**: prose

**Scope Hypothesis**: This phase asserts the carry-forward machinery lives in exactly three
places — `conclusion-stage.md`'s `## Two Flags` section (its heading at roughly line 149), Step
5's carry-forward sentence (roughly line 356) and Step 6's trailing clause, plus the template's
`{roadmap_flags}` placeholder. These line positions were established by plan-time greps
(`grep -n 'Two Flags\|Carry forward\|roadmap_flags'`) and are hypotheses about a tree a sibling
may move: confirm at implementation time by re-running that same grep and matching on the text,
never on the line number.

**Tier Justification**: Both files are pure-guidance markdown with no executable surface
(`suite_selection_select` returns `__FULL_SWEEP__`), so the honest covering check is
`bash .claude/scripts/verify-deploy.sh --only-gate 3,4` plus a diff read-through confirming the
edits stay inside prose and inside the template's fenced example.

**Files to modify**:
- `agent-system/extensions/core/context/contracts/conclusion-stage.md` - replace the Two Flags section with a current-state pointer; drop Step 5's carry-forward instruction and Step 6's flags clause
- `agent-system/extensions/core/context/patterns/orchestrate-batch-results-template.md` - simplify the `### Conclusion` block's `**Roadmap**` line, dropping the `{roadmap_flags}` placeholder

**Verification**:
- `grep -rn 'Two Flags' agent-system/` returns nothing
- `grep -n 'roadmap_flags' agent-system/extensions/core/context/patterns/orchestrate-batch-results-template.md` returns nothing
- `grep -n 'Carry forward' agent-system/extensions/core/context/contracts/conclusion-stage.md` returns nothing
- `grep -n '^### Conclusion' agent-system/extensions/core/context/patterns/orchestrate-batch-results-template.md` still returns exactly one match, and the file's header still says eleven `###`-level subsections (count unchanged)
- `conclusion-stage.md`'s new current-state subsection resolves to `context/patterns/roadmap-update.md` and names both discharged items
- `bash .claude/scripts/verify-deploy.sh --only-gate 3,4` exits 0
- `git status --short` and `git diff --staged` reviewed before commit; only these two files staged

---

### Phase 4: Redeploy and Run the Full Gate Set [COMPLETED WITH EXCLUSIONS]

**Goal**: Propagate the source-store edits into the deployed `.claude/` tree and confirm the
whole repository is green.

**Tasks**:
- [x] Confirm the working tree holds only this task's own uncommitted changes before deploying;
      if a foreign uncommitted modification or a foreign commit is present, check `git log` to
      confirm it is not this task's own work and STOP and report rather than proceeding
      *(completed: found `agent-system/extensions/core/scripts/roadmap-integration.sh` and
      `scripts/tests/test-roadmap-generation.sh` live-dirty, confirmed via `git log` to be
      sibling task 371's own in-progress work on top of its committed phase 1-4 history
      (e23447a65/97f19e4f5/b28550fcc). STOPPING here per this task's own instruction and the
      territory contract — see deviation note below)*
- [x] Redeploy: `bash .claude/scripts/deploy-headless.sh`
      *(completed: sibling task 371 is now `completed` and terminal with a clean working tree
      for its own two files; the collision this entry previously deferred on is resolved. Ran
      `bash .claude/scripts/deploy-headless.sh` — landed (exit 0); its own inline
      `verify-deploy.sh --skip-slow` pass reported 1 of 35 failed (doc-lint, Gate 3 — see this
      phase's Reasoned Exclusions below), distinct from the deploy landing itself, which
      succeeded)*
- [x] Confirm source/deployed parity for all four scoped files with the same `diff -q` loop
      Phase 1 used
      *(completed: re-run both before and after the redeploy; all four `diff -q` invocations
      exit 0 both times)*
- [x] Run the complete gate set: `bash .claude/scripts/verify-deploy.sh`
      *(completed: full run (no `--skip-slow`), 2 of 36 checks failed — Gate 3 (doc-lint) and
      Gate 8 (`run-all.sh`). See this phase's Reasoned Exclusions below)*
- [x] If a gate fails in a file outside this plan's four-file scope, treat it as possibly a
      sibling task's in-flight edit — check `git log` and the file's authorship before attributing
      it to this task's work, and report rather than "fixing" a sibling's file
      *(completed: both Gate 3 and Gate 8's failing files were checked against `git log` and
      confirmed unrelated to this task's four-file scope and to sibling tasks 371/373's live
      edits — see Reasoned Exclusions below)*
- [x] Commit any deploy-produced changes to `.claude/**` by explicit path list, if the deploy
      leaves tracked changes
      *(completed: `.claude/` is entirely gitignored in this repository — `git status --porcelain`
      shows zero `.claude/` entries before or after the redeploy, so there is nothing to commit;
      this task item is a no-op by design, not a skip)*
- [x] Record the gate run's result (green, with the command and its exit status) for the summary
      *(completed: recorded below and in the implementation summary — 2 of 36 failed, both
      attributed and excluded, not fixed)*

**Timing**: 0.5 hours

**Depends on**: 3

**Verification Tier**: full

**Scope Hypothesis**: This phase asserts that the deploy's effect on the tracked tree is confined
to the four deployed counterparts of this plan's four source-store files. That is a hypothesis
about a run that has not happened yet: `deploy-headless.sh` regenerates the whole `.claude/`
tree, and a sibling's source-store edit landing in the same cycle can legitimately widen the
diff. Confirm at implementation time with `git status --short` after the deploy, and attribute
any deployed-file change outside those four to its originating source-store edit (checking
`git log`) before committing or reporting it.

**Files to modify**:
- none planned — this phase hand-authors nothing. `deploy-headless.sh` regenerates the deployed
  `.claude/` counterparts of the four source-store files edited in Phases 2-3; per
  `rules/source-store-deploy-boundary.md` those copies are disposable deploy artifacts and are
  never an edit target

**Verification**:
- `bash .claude/scripts/deploy-headless.sh` exits 0 — confirmed (deploy landed)
- All four `diff -q` source-vs-deployed invocations exit 0 — confirmed, both before and after
  the redeploy
- `bash .claude/scripts/verify-deploy.sh` — the complete gate set, not a selected subset and not
  `--skip-slow`: ran and reported 2 of 36 checks failed, both pre-existing and out of this task's
  scope (see Reasoned Exclusions below); does not exit 0 as the criterion originally anticipated,
  admitted under `[COMPLETED WITH EXCLUSIONS]`
- `git status --short` shows no unexpected foreign modifications attributed to this task —
  confirmed: the two failing gates' files are clean and last touched by old, unrelated commits

#### Reasoned Exclusions

| Item | Reason | Evidence |
|------|--------|----------|
| Gate 8 (`tests/run-all.sh`) failure: `test-verify-deploy-context-budget.sh` | Pre-existing defect owned by sibling task 371's file scope, not task 372's. The fixture runs `git init` but never `git add`, so the gate's own Gate 22 discovers files via `git ls-files` against an empty index, finds zero `.sh` files, and exits 2. Recorded by task 371 itself as `371:iss_1791597799615_hKfFjt`, and independently corroborated by this orchestration cycle's own baseline (pre=1 post=1 new=0). Editing a sibling task's fixture file is out of this task's declared scope. | `bash agent-system/extensions/core/scripts/tests/run-all.sh` output: "Failing suites (1): .../test-verify-deploy-context-budget.sh (NEW)"; `371:iss_1791597799615_hKfFjt` |
| Gate 3 (`check-extension-docs.sh`, doc-lint) failure on `core`: `script referenced in docs/skills/agents but NOT in provides.scripts: check-evidence-probes.sh` | Newly observed during this phase (not previously documented for this task), but confirmed pre-existing and unrelated to task 372's four-file scope or to siblings 371/373. The two referencing comments (`skills/skill-todo/SKILL.md:550` and `context/patterns/task-abandon-mode.md:72`) are clean — no uncommitted edits — and were last touched by old, unrelated commits (`7ffb39166` and earlier). `check-evidence-probes.sh` does not exist as a file; both comments describe it as a "WIRED_REPO form ... must be re-pointed, or the file promoted" — a known-aspirational reference predating this task, not a regression it introduced. Recorded as `372:iss_1791742848757_BcRCvu` (`--resolution open`, `--suggested-channel follow_up_task`). | `bash .claude/scripts/check-extension-docs.sh` output: "[core] FAIL: script referenced in docs/skills/agents but NOT in provides.scripts: check-evidence-probes.sh"; `git log -3` on both referencing files shows no recent/uncommitted edit; `372:iss_1791742848757_BcRCvu` |

Both exclusions satisfy the five-condition admission test in
`context/standards/status-markers.md`'s `[COMPLETED WITH EXCLUSIONS]` subsection: each is a
specific, enumerated item (not a blanket "tests fail"); each carries a reason and evidence;
neither is this task's own file_scope; neither blocks a future task from acting on it (both are
independently tracked, one by task 371's own issue log, the other by a new issue filed against
task 372); and the exclusion is recorded here rather than silently skipped.

---

## Testing & Validation

- [x] The `### Conclusion` report block exists in `orchestrate-batch-results-template.md` and
      `conclusion-stage.md`'s Step 6 pointer resolves to it (acceptance criterion 1, satisfied by
      verification with recorded evidence rather than by a new diff)
- [x] `roadmap-update.md` names `/orchestrate`'s conclusion stage as a caller of `--regenerate`
      (acceptance criterion 2)
- [x] The `/todo`//`review` unwired-mode question is closed by an explicit recorded ruling in
      `roadmap-update.md` (acceptance criterion 3)
- [x] Both items `conclusion-stage.md`'s `## Two Flags` section flagged are discharged, and that
      section no longer flags resolved gaps (acceptance criterion 4)
- [x] No stale "no live caller" claim survives anywhere under `agent-system/**`
- [x] No task-number reference lands in any file under `agent-system/**`
- [x] No record-versioning language lands in any edited file
- [x] `bash .claude/scripts/verify-deploy.sh` *(deviation: altered — reports 2 of 36 failed, both
      pre-existing and excluded per Phase 4's Reasoned Exclusions, not a clean 36/36; the
      `--skip-slow` path alone fails 1 of 35 on the same Gate 3 finding)*
- [x] Source-store and deployed copies are byte-identical for all four scoped files

## Artifacts & Outputs

- Edited: `agent-system/extensions/core/context/patterns/roadmap-update.md`
- Edited: `agent-system/extensions/core/context/contracts/conclusion-stage.md`
- Edited: `agent-system/extensions/core/context/patterns/orchestrate-batch-results-template.md`
- Edited: `agent-system/extensions/core/docs/reference/utility-scripts-inventory.md`
- Redeployed: the four corresponding `.claude/**` copies
- `specs/372_conclusion_stage_report_block_and_caller_split/summaries/01_conclusion-report-block-caller-split-summary.md`
- Issue-log entries under the task directory, recorded as they arise

## Rollback/Contingency

Every change is a documentation/contract prose edit in four markdown files, committed one phase
at a time with an explicit path list. To revert a phase, `git revert` that phase's commit and
re-run `deploy-headless.sh`; nothing executable changes, so no build or data state depends on
these edits.

If a sibling task's concurrent edit makes a clean revert impossible, do not run
`git-snapshot.sh` in its reverting default mode on this shared tree — use `--no-revert` for a
defensive checkpoint and report the collision instead, per the dispatch's concurrency note and
`context/contracts/territory.md`'s Cross-Task Territory section.

If Phase 1 finds that task 371 has changed the generator's mode set, stop before Phase 2 and
report: the caller contract's wording depends on `--regenerate`/`--prune` continuing to mean what
they mean today, and a wrong caller sentence is worse than a missing one.
