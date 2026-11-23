# Implementation Plan: Task #691

- **Task**: 691 - Restack review stack when parent merges
- **Status**: [NOT STARTED]
- **Effort**: 2 hours
- **Dependencies**: None (the parent plan's Phase 3, which this phase depends on, has already landed)
- **Research Inputs**: specs/691_restack_review_stack_when_parent_merges/reports/01_restack-on-parent-merge.md
- **Artifacts**: plans/01_restack-on-parent-merge.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

This record owns exactly one phase of the stack-PR-submission design record
(`specs/685_stack_pr_submission_from_integration_branch/plans/01_stack-pr-submission.md`,
Phase 4, "Restack when a parent merges"), whose prose and decisions PD1/PD6/PD7/PD8/PD9 remain
the authoritative design. The deliverable is the `restack` subcommand of
`agent-system/extensions/core/scripts/review-stack-prepare.sh`, plus its suite cases. Every git
primitive the subcommand needs already exists in that file and is proven by the landed `cut`
implementation; no new primitive, no new static-assertion exemption, and no doc file outside the
script's own self-documenting header are required.

The decomposition mirrors the shape `cut` already has in the same file —
`rsp_cut_plan` / `rsp_cut_print` / `rsp_cut_execute` — so each phase lands a self-consistent,
independently green deliverable: Phase 1 resolves every input and refuses on anything
unresolvable while writing nothing; Phase 2 fills detection and the full disposition plan,
computing every descendant commit off-tree and still writing nothing (this is where "a conflict
refuses and moves nothing" becomes a structural property rather than a careful ordering); Phase 3
moves refs by compare-and-swap, rewrites the manifest, and redeploys.

### Research Integration

The research report confirmed, against the live file rather than the description's prose:

- `rsp_move_commit_onto_new_parent` (three-way `git merge-tree --write-tree`, refusing 48 and
  naming the conflicting path) and the `git commit-tree` + three-argument `git update-ref`
  compare-and-swap idiom in `rsp_cut_execute` are directly reusable. No new git primitive.
- The manifest already carries every field `restack` reads or updates
  (`ordinal`, `tasks`, `branch`, `base`, `commit`, `parent_commit`, `title`, `body_path`,
  `state`, `request`). `state` is today always written `"prepared"`; `restack` is its first
  writer of `"merged"`.
- `restack` has no dispatch arm at all today — any `restack` invocation falls through to the
  generic "subcommand body not yet implemented" NOTE branch, including one given `--stack-id`.
- `--merged NN` is a genuinely new flag and must be kept lexically distinct from the existing
  `--merge N+M` (cut-only, forces two tasks into one unit).
- The `refs/remotes/<remote>/HEAD` probe has an exact existing idiom to replicate inline
  (`git symbolic-ref --short`, empty on failure) rather than import across files.
- The suite's fixture scaffolding needs no extension: the Phase 3 moved-base and
  unknown-remote-commit cases already simulate remote state by writing
  `refs/remotes/<remote>/<branch>` directly with `git update-ref`, with no push, fetch, or
  `git merge` anywhere.

The report's three named ambiguities in PD7's prose are resolved as plan-level decisions D1-D3
below rather than left to be re-derived from the prose a second time during implementation.

### Carried-Figure Re-Validation

Every measurable claim in the dispatch description was checked against live state before this
plan was written. All four confirm the description unchanged:

| Claim | Status | Evidence |
|-------|--------|----------|
| `review-stack-prepare.sh` carries `cut`, `show`, `record-request`, the shared resolvers, selection/attribution/union-find/ordering, and the manifest writer | Confirmed | Live file is 1219 lines; dispatcher at lines 1204-1218 has arms for `cut`, `show`, `record-request` only |
| Exit codes run contiguously through 52 | Confirmed | Header table (lines 94-119) ends at `52 record_request_entry_not_found`; no `rsp_refuse` call site uses a code above 52 |
| The suite stands at 38 passing cases | Confirmed | `bash agent-system/extensions/core/scripts/tests/test-review-stack-prepare.sh` printed `Results: 38 passed, 0 failed` on 2026-11-23 |
| Two static assertions (no push/checkout/switch/merge/rebase/replay/gh/glab; no literal origin/main/master/upstream outside comments) pass | Confirmed | Both named in that same green run; source at test file lines 688-701 |

One figure inherited from the parent plan's Phase 4 section is now **stale and corrected here**:
that section's Scope Hypothesis and Tier Justification both stated the touched-path selector's
entire output for this phase's two paths was the `__FULL_SWEEP__` sentinel "because neither file
exists yet". Both files now exist. Re-running the selector over the phase's whole `Files to
modify` set in one invocation:

```
bash agent-system/extensions/core/scripts/verify-touched.sh \
  agent-system/extensions/core/scripts/review-stack-prepare.sh \
  agent-system/extensions/core/scripts/tests/test-review-stack-prepare.sh
```

resolves to exactly one real suite, `test-review-stack-prepare.sh`, with no sentinel in the
output (`1 suite(s) selected, 0 owed, 0 no-suite-by-class, across 2 touched path(s)`, exit 0).
Every Tier Justification below names that measured result, not the parent plan's superseded
sentinel prediction.

### Prior Plan Reference

The parent design record's Phase 4 section is the authoritative task list and is reproduced
faithfully as this plan's work, not copied as phase structure: that one 1.5-hour phase is split
into three here, along the `plan` / `print` / `execute` seam the same file already uses for
`cut`, so that each phase closes green on its own. Effort is calibrated upward from the parent's
1.5 hours to 2 hours on the evidence of Phases 1-3, which ran at roughly one phase per dispatch
and each exceeded their own estimate; the three-way split also absorbs the per-phase suite work
the parent's single estimate folded together.

### Roadmap Alignment

No `roadmap_path` was provided in this dispatch and `roadmap_flag` is not set on this task, so no
roadmap phases are added and no roadmap consultation was performed.

## Goals & Non-Goals

**Goals**:

- `restack --stack-id NAME [--merged NN]` reads the stack's manifest and the review base's
  remote-tracking ref, never fetching; an absent ref refuses and prints the fetch the operator
  runs.
- A merged bottom-of-stack entry is detected per PD7, bottom-up: its state becomes `merged` and
  the next entry's base becomes the review base.
- Each descendant is recomputed with the three-way `merge-tree` onto its new parent, written with
  `git commit-tree`, and its ref moved by compare-and-swap; a conflict refuses, names the path,
  and moves nothing.
- A local review ref disagreeing with its remote-tracking ref in a way the manifest does not
  explain refuses, and the refusal says which kind of ref disagreed.
- Per restacked branch, `/please push <remote> <branch> --force-with-lease` is printed, plus once
  `/merge --stack <stack id> --retarget`; an absent `refs/remotes/<remote>/HEAD` prints
  `git remote set-head <remote> -a` first with the reason.
- Nothing merged is reported as such and changes nothing; a base that moved without a merged entry
  is reported as a stale stack with the restack it would perform.
- The suite's existing 38 cases pass unmodified, both static assertions still pass unmodified, and
  new cases cover the four paths the dispatch names plus the parent plan's own named cases.

**Non-Goals**:

- No push, checkout, switch, merge, rebase, replay, `gh`, or `glab` invocation is added, and no
  literal `origin`/`main`/`master`/`upstream` word lands outside a comment. The two static
  assertions enforcing this stay unmodified; an assertion that had to be edited to pass is
  evidence the change is wrong, not evidence the assertion is stale.
- No fetch. `--merged NN` does not substitute for the remote-tracking ref this script is
  constitutionally forbidden from fetching (D3).
- No file outside this task's declared `file_scope` is edited. In particular
  `context/standards/repo-level-declarations.md` is NOT extended with a restack-time refusal
  table here, even though the research report identifies that as a real gap the parent plan's own
  later phase owns.
- No PR, no MR, no remote write. The printed commands are prepared for an operator, never run.
- No new library, no extraction of an existing private helper into a shared library (PD10).

## Decisions

These resolve the three ambiguities the research report identified in PD7's prose, plus three
narrower choices it surfaced. They are stated here so implementation reads them once rather than
re-deriving them.

- **D1. "The parent" in the detection test is the bottom-of-stack entry's own review commit.**
  For the current bottom entry `E`, whose manifest `base` field names the review base, a merge is
  detected when either holds against the review base's remote-tracking sha `R`:
  - *ancestry*: `git merge-base --is-ancestor <E.commit> <R>` succeeds (fast-forward,
    rebase-and-merge, or a merge commit whose history contains `E.commit`); or
  - *squash*: `rsp_move_commit_onto_new_parent <E.parent_commit> <R> <E.commit>` yields a tree
    identical to `<R>^{tree}` — merging `E`'s diff into the already-landed tip introduces no
    further change because it is already there.

  This gives `rsp_move_commit_onto_new_parent` two call sites (detection and recompute), which is
  PD6's "one primitive serves the first cut and every restack" intent applied to this phase as
  well.

- **D2. The disagreement refusal splits into two reasons, not one.** Reuse exit 49
  (`unknown_remote_commit`) unchanged for any stack branch `restack` is about to move whose
  remote-tracking ref holds a commit the manifest does not record — the exact case
  `rsp_cut_execute`'s existing guard covers. Add one new code for the review base's own
  local-vs-remote-tracking divergence, which the manifest never records and so cannot explain.
  Collapsing both into one code would make a refusal message ambiguous about which ref
  disagreed, working against the "refuses, naming the path" requirement.

- **D3. `--merged NN` is an optional override that never bypasses the ref requirement.** The
  remote-tracking-ref-absent refusal fires unconditionally, including when `--merged NN` is
  supplied. `--merged NN` only changes which already-visible entry is treated as merged, for the
  case where detection cannot run even though the operator knows the entry landed.

- **D4. Compute every descendant commit before moving any ref.** `restack` runs in two passes:
  the plan pass computes each descendant's new tree and commit off-tree and refuses 48 on the
  first conflict; the execute pass moves refs only after every commit exists. This makes "a
  conflict moves nothing" structural rather than a property of careful ordering, and it is why
  the conflict case is testable in Phase 2 before any ref-moving code exists.

- **D5. `show`'s human-readable output starts printing `state`.** Today only `--json` exposes it,
  because it was always `"prepared"`. Once `restack` can write `"merged"`, an operator needs to
  see which entries have merged without reaching for `--json`.

- **D6. Reuse exit 41 (`stack_id_required`) for a `restack` given no `--stack-id`**, rather than a
  fourth near-duplicate reason string for the same situation. The reason vocabulary stays small;
  the message text names the subcommand.

- **D7. New exit codes are allocated at 53 and 54**, the next free values after 52:
  - `53 review_base_remote_ref_absent` — the review base's remote-tracking ref does not exist;
    the refusal prints the fetch the operator runs.
  - `54 review_base_ref_divergence` — the review base's local ref and its remote-tracking ref
    disagree in a way the manifest does not explain (D2's second case).

  Re-read the live header table immediately before allocating, per the territory contract's
  re-read-before-editing rule; the table was contiguous through 52 as of this plan's authoring.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| A new ref-moving or detection step introduces a forbidden primitive and a static assertion is edited to make the suite pass | H | L | Every primitive this plan names (`merge-tree`, `merge-base`, `merge-base --is-ancestor`, `commit-tree`, `update-ref`, `symbolic-ref`, `rev-parse`, `for-each-ref`) is already used elsewhere in the same file under the same assertions. Each phase's verification re-runs both static checks and asserts they are byte-identical to their pre-phase form. |
| `--merged NN` is implemented as bypassing the remote-tracking-ref-absent refusal, silently weakening the no-fetch constraint | H | L | D3 states the ordering. Phase 1 lands a suite case asserting the refusal fires even with `--merged NN` supplied and no remote-tracking ref present. |
| `--merged` is confused with the existing cut-only `--merge N+M` in the parser, the header, or a refusal message | M | M | Phase 1 adds the flag in a separate parser arm with a distinct variable name and documents both in the USAGE block with their differing meanings side by side. |
| A conflicting descendant leaves earlier descendants' refs already moved | H | L | D4's two-pass ordering makes this structurally impossible. Phase 2's conflict case asserts the refusal before any execute code exists; Phase 3 re-asserts it with the execute path present and checks every ref is byte-identical afterwards. |
| An exit code collides with a value a concurrent sibling reserved in the same file | L | L | Siblings 692 and 693 touch disjoint files (`milestone-review-handoff.sh`, `merge.md`, `skill-git-workflow/SKILL.md`), none of which carries this script's exit-code table. Still re-read the live table immediately before editing. |
| The manifest is rewritten with a merged entry's state but the descendant refs did not move (or vice versa), leaving an inconsistent stack | M | L | Phase 3 writes the manifest only after every ref move has succeeded, and reuses the same whole-file rewrite the existing manifest writer performs rather than an in-place per-entry patch. |
| A task-number reference or record-versioning phrase lands in the script or suite | M | M | Both files sit under `agent-system/**`, where both are prohibited. Fixture task numbers follow the suite's existing synthetic 9xx convention; every phase's verification includes the task-reference lint via the touched-path check. |

## Implementation Phases

**Dependency Analysis**:

| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2 | 1 |
| 3 | 3 | 2 |

Phases within the same wave can execute in parallel. This plan is a strict chain: each phase
extends the function the previous one introduced, so there is no parallelism to exploit.

---

### Phase 1: Flag, dispatch arm, and the ref-resolution refusal surface [NOT STARTED]

**Goal**: `restack --stack-id NAME [--merged NN]` parses, dispatches to its own body, resolves
every input it needs — the manifest, the review base's remote-tracking ref, and the review base's
local-vs-remote agreement — and refuses by name on anything unresolvable, writing no ref, no
manifest, and no file.

**Tasks**:

- [ ] Re-read the live header table (`EXIT CODES` block) and the live flag parser before editing,
      per the territory contract, and confirm 53/54 are still the next free values.
- [ ] Add a `--merged` arm to the flag parser, storing its value in a variable whose name cannot
      be confused with the existing `MERGE_PAIRS` that `--merge N+M` feeds. Validate it is a
      bare entry ordinal in the same `NN` form `record-request` already takes.
- [ ] Add the `elif [ "$subcommand" = "restack" ] && [ -n "$stack_id" ]; then` dispatch arm,
      parallel to the existing `show` and `record-request` arms, calling a new
      `rsp_restack_plan`. A `restack` with no `--stack-id` refuses 41 per D6 with a message
      naming the subcommand.
- [ ] In `rsp_restack_plan`: load the stack's manifest, reusing exit 50 (`manifest_missing`)
      unchanged when none is on disk.
- [ ] Resolve the review base's remote-tracking ref without fetching. Refuse 53
      (`review_base_remote_ref_absent`) when it does not exist, printing the exact fetch command
      the operator runs. Per D3 this refusal fires unconditionally, including when `--merged NN`
      is supplied.
- [ ] Check the review base's local ref against that remote-tracking ref. Refuse 54
      (`review_base_ref_divergence`) when they disagree in a way the manifest does not explain,
      with a message that says it is the review base's own ref that disagreed (D2) and names
      both shas.
- [ ] Probe `refs/remotes/<remote>/HEAD` with the inline `git symbolic-ref --short` idiom
      (empty on failure), replicating `push-grant-lib.sh`'s shape rather than importing it, and
      record whether it is absent for Phase 2's printed output to use.
- [ ] Print the resolved disposition skeleton: one line per manifest entry with its ordinal,
      branch, current `state`, and current `base`. Write nothing. (Detection fills this in
      Phase 2.)
- [ ] Extend the header's `USAGE` block with `[--merged NN]` and the `EXIT CODES` table with 53
      and 54, in the same edit, documenting `--merged NN` and `--merge N+M` side by side with
      their differing meanings.
- [ ] Suite cases: `restack` with no `--stack-id` refuses 41; `restack` against a stack with no
      manifest refuses 50; an absent review-base remote-tracking ref refuses 53 and the printed
      output contains the fetch command; the same refusal fires with `--merged NN` supplied; a
      review base whose local and remote-tracking refs diverge unexplainedly refuses 54 and the
      message names the review base ref rather than a stack branch; every one of these leaves
      `HEAD`, the index, `git status --porcelain`, every ref, and the manifest byte-identical.

**Timing**: 0.5 hours

**Depends on**: none

**Verification Tier**: local

**Scope Hypothesis**: This phase asserts that 53 and 54 are the next free exit codes, that the
suite's existing case count is 38, and that its own edits stay inside the two files this task's
`file_scope` declares. Confirm each at implementation time: re-read the live `EXIT CODES` table
before allocating; run the suite before editing and record the pre-edit `Results:` line; and run
`git status --short` before each commit to confirm no third path appears.

**Tier Justification**: `bash agent-system/extensions/core/scripts/verify-touched.sh agent-system/extensions/core/scripts/review-stack-prepare.sh agent-system/extensions/core/scripts/tests/test-review-stack-prepare.sh` resolves this phase's whole `Files to modify` set to exactly one real suite, `test-review-stack-prepare.sh`, with no sentinel in its output, and that suite is this phase's own direct coverage.

**Files to modify**:

- `agent-system/extensions/core/scripts/review-stack-prepare.sh` - `--merged` parser arm,
  `restack` dispatch arm, `rsp_restack_plan`'s resolution and refusal half, header `USAGE` and
  `EXIT CODES` blocks
- `agent-system/extensions/core/scripts/tests/test-review-stack-prepare.sh` - five refusal cases
  and their writes-nothing assertions

**Verification**:

- `bash agent-system/extensions/core/scripts/tests/test-review-stack-prepare.sh` exits 0, its
  `Results:` line shows the pre-edit 38 plus this phase's new cases, and no pre-existing case or
  assertion was edited.
- Both static assertions pass and `git diff` shows their source lines unchanged.
- `bash agent-system/extensions/core/scripts/verify-touched.sh` over this phase's two paths exits
  0.

---

### Phase 2: Bottom-up detection and the full disposition plan [NOT STARTED]

**Goal**: `restack` states a disposition for every entry — merged, restacked onto a new parent,
or unchanged — computes every descendant's new commit off-tree, prints the operator's commands,
and still writes nothing. This is the complete `--dry-run` deliverable.

**Tasks**:

- [ ] Implement bottom-up merge detection per D1: for the current bottom entry, the ancestry test
      (`git merge-base --is-ancestor <entry commit> <remote-tracking sha>`) or the squash test
      (`rsp_move_commit_onto_new_parent <entry parent_commit> <remote-tracking sha> <entry commit>`
      yielding a tree equal to the remote-tracking commit's tree). Iterate bottom-up so a run of
      consecutively merged entries is all detected in one pass.
- [ ] Apply `--merged NN` as an override per D3: the named ordinal is treated as merged even when
      neither test fires, after the Phase 1 ref requirement has already been satisfied. Refuse
      when `NN` does not name an entry in this stack's manifest, reusing 52
      (`record_request_entry_not_found`) rather than a new code.
- [ ] Compute the disposition: each merged entry's state becomes `merged`; the next surviving
      entry's base becomes the review base; each remaining descendant's new parent is the entry
      below it in the restacked order.
- [ ] Per D4, compute every descendant's new tree with `rsp_move_commit_onto_new_parent` and its
      new commit with `git commit-tree` in this pass, before any ref is touched. The first
      conflict refuses 48 (`ref_conflict`) naming the path, with nothing moved and nothing
      written.
- [ ] Implement the nothing-merged report: when no entry is detected as merged and no `--merged`
      override applies, say so and change nothing.
- [ ] Implement the stale-stack report: a review base whose remote-tracking ref has moved past
      the manifest's recorded base without any entry having merged is reported as a stale stack,
      naming the restack it would perform.
- [ ] Implement `rsp_restack_print`: per restacked branch,
      `/please push <remote> <branch> --force-with-lease` — the same two-token
      `push <remote> <branch>` form `show` already prints and `please-grant.sh` already parses,
      with the lease flag appended, not the alternate "push BRANCH to REMOTE" form. Once, after
      the per-branch lines, `/merge --stack <stack id> --retarget`. When
      `refs/remotes/<remote>/HEAD` was found absent in Phase 1, print
      `git remote set-head <remote> -a` first with the reason it is needed.
- [ ] Suite cases: a bottom entry squash-merged into the review base's remote-tracking ref is
      detected (fixture advances that ref via `git commit-tree` + `git update-ref` only, never a
      push, fetch, or `git merge`); a merge-commit parent is detected by ancestry (fixture builds
      a two-parent commit with `git commit-tree -p <old tip> -p <entry commit>`); a conflicting
      descendant refuses 48, names the path, and leaves every ref and the manifest
      byte-identical; no merged parent is a no-op that reports as such and changes nothing; a
      moved base with no merged entry reports as a stale stack; `--merged NN` naming a
      non-existent ordinal refuses 52; the printed output for a clean detection contains one
      `/please push ... --force-with-lease` per restacked branch and exactly one
      `/merge --stack ... --retarget`; the `git remote set-head` line appears when and only when
      `refs/remotes/<remote>/HEAD` is absent.

**Timing**: 0.75 hours

**Depends on**: 1

**Verification Tier**: local

**Scope Hypothesis**: This phase asserts the suite's case count grows from Phase 1's closing
figure without any existing case changing, and that detection needs no git primitive beyond those
already present in the file. Confirm both at implementation time: record the pre-edit `Results:`
line and diff it against the post-edit one; and re-run both static assertions, whose passing is
itself the check that no forbidden primitive was introduced.

**Tier Justification**: `bash agent-system/extensions/core/scripts/verify-touched.sh agent-system/extensions/core/scripts/review-stack-prepare.sh agent-system/extensions/core/scripts/tests/test-review-stack-prepare.sh` resolves this phase's whole `Files to modify` set to exactly one real suite, `test-review-stack-prepare.sh`, with no sentinel in its output, and this phase writes no ref and no file, so nothing outside that suite's reach can change behavior.

**Files to modify**:

- `agent-system/extensions/core/scripts/review-stack-prepare.sh` - detection, `--merged`
  override, disposition computation, off-tree descendant recompute, `rsp_restack_print`
- `agent-system/extensions/core/scripts/tests/test-review-stack-prepare.sh` - detection,
  no-op, stale-stack, conflict, and printed-output cases

**Verification**:

- `bash agent-system/extensions/core/scripts/tests/test-review-stack-prepare.sh` exits 0 with no
  pre-existing case or assertion edited.
- Both static assertions pass with their source lines unchanged.
- The conflict case's assertion that every ref and the manifest are byte-identical after the
  refusal was observed passing, which is the structural check on D4.
- `bash agent-system/extensions/core/scripts/verify-touched.sh` over this phase's two paths exits
  0.

---

### Phase 3: Move refs, rewrite the manifest, and redeploy [NOT STARTED]

**Goal**: A detected merge is committed to disk: each descendant's ref moves by compare-and-swap,
the manifest records the merged entry's new state and each moved entry's new base and commit,
`show` reports `state` to an operator, and the regenerated deploy tree carries the result.

**Tasks**:

- [ ] Implement `rsp_restack_execute`, called only when not `--dry-run`, running after Phase 2's
      plan pass has computed every new commit (D4).
- [ ] Before moving each descendant's ref, apply the existing per-branch guard: when that
      branch's remote-tracking ref holds a commit the manifest does not record, refuse 49
      (`unknown_remote_commit`) unchanged, reusing the message shape `rsp_cut_execute` already
      carries so the refusal names the stack branch rather than the review base (D2).
- [ ] Move each descendant's ref with the three-argument `git update-ref <ref> <new> <old>`
      compare-and-swap, `<old>` being the sha the manifest recorded. A failed swap refuses 48 in
      the same shape `rsp_cut_execute` uses, naming the ref that moved concurrently.
- [ ] Rewrite the manifest only after every ref move has succeeded: each merged entry's `state`
      becomes `merged`, the new bottom entry's `base` becomes the review base, and each moved
      entry's `base`, `commit`, and `parent_commit` are updated. Preserve every field the writer
      does not own, `request` in particular, exactly as the existing re-cut path preserves it.
- [ ] Extend `rsp_show_stack`'s human-readable output to print each entry's `state` (D5). The
      `--json` form, which emits the manifest verbatim, needs no change.
- [ ] Re-read the header's `USAGE` and `EXIT CODES` blocks and reconcile them against the
      finished implementation — the `restack` usage line, 53, 54, and the fact that `state` can
      now be `merged`. This block is this script's authoritative self-contained documentation and
      is inside this task's `file_scope`; confirm it exists and is still contiguous before
      editing, and if the live table has drifted from what Phase 1 left, reconcile to the live
      file rather than to this plan's text.
- [ ] Confirm no task-number reference and no record-versioning phrase landed in either file;
      both sit under `agent-system/**`, where both are prohibited.
- [ ] Redeploy the source store into the deployed tree:
      `bash .claude/scripts/deploy-headless.sh` (read its header for the `TARGET_REPO` argument
      contract before running). The deployed `.claude/` tree is gitignored, so this produces
      nothing to commit; it is what makes the change live for the deployed entry points.
- [ ] Suite cases: a clean bottom-up restack moves every descendant's ref, the manifest records
      the merged entry as `merged` and the new bottom's base as the review base, and each
      descendant's three-dot diff against the new base lists only its own paths; the same with a
      foreign commit on the review base, whose line survives the restack; a descendant whose
      remote-tracking ref holds an unrecorded commit refuses 49 naming that branch; a
      compare-and-swap that loses a race refuses 48; Phase 2's conflict case re-asserted with the
      execute path present, confirming every ref is still byte-identical; `show`'s
      human-readable output prints `merged` for a merged entry; and `HEAD`, the index, and
      `git status --porcelain` are unchanged across every one of these.

**Timing**: 0.75 hours

**Depends on**: 2

**Verification Tier**: full

**Scope Hypothesis**: This phase asserts that the existing 38 cases still pass unmodified, that
the per-phase case additions sum to a suite whose `Results:` line shows zero failures, and that
the redeploy regenerates the whole deployed tree (declared below as `__WHOLE_TREE__`). Confirm at
implementation time: diff the suite file to show no pre-existing case or assertion was edited;
read the final `Results:` line; and read `deploy-headless.sh`'s own output for what it
regenerated rather than assuming.

**Files to modify**:

- `agent-system/extensions/core/scripts/review-stack-prepare.sh` - `rsp_restack_execute`, the
  per-branch 49 guard, compare-and-swap ref moves, the manifest rewrite, `rsp_show_stack`'s
  `state` column, header reconciliation
- `agent-system/extensions/core/scripts/tests/test-review-stack-prepare.sh` - clean restack,
  foreign-line, unknown-remote-commit, lost-race, re-asserted conflict, and `show`-state cases
- `__WHOLE_TREE__` - the redeploy step regenerates the entire deployed `.claude/` tree

**Verification**:

- `bash agent-system/extensions/core/scripts/tests/test-review-stack-prepare.sh` exits 0, its
  `Results:` line shows zero failures, and `git diff` over the suite file confirms the original
  38 cases and both static assertions are present unmodified.
- The stale-stack assertion was observed in both states: a descendant's three-dot diff lists the
  parent's files before the restack and not after.
- `bash agent-system/extensions/core/scripts/verify-touched.sh agent-system/extensions/core/scripts/review-stack-prepare.sh agent-system/extensions/core/scripts/tests/test-review-stack-prepare.sh` exits 0 — the scoped touched-path check that discharges this phase's own in-dispatch obligation.
- The complete gate set this `full` tier owes is **deferred to the orchestration close**
  (`context/contracts/batch-gate-stage.md`'s once-per-invocation batch gate stage), not run
  independently by this phase. Record that deferral in the phase's own verification notes.
- `bash .claude/scripts/deploy-headless.sh` completed without error and reported the regenerated
  tree.

---

## Testing & Validation

- [ ] `bash agent-system/extensions/core/scripts/tests/test-review-stack-prepare.sh` exits 0.
- [ ] The suite's pre-existing 38 cases are present and unmodified; `git diff` over the suite file
      shows only additions and no edited assertion. An existing assertion that had to be edited to
      pass is treated as evidence the change is wrong.
- [ ] Both static assertions pass and their source lines are byte-identical to their pre-task form:
      no push/checkout/switch/merge/rebase/replay/`gh`/`glab` invocation, and no literal
      `origin`/`main`/`master`/`upstream` word outside a comment.
- [ ] The four paths the dispatch names are each covered by at least one case: a clean bottom-up
      restack, a conflicting descendant that refuses and moves nothing, an absent
      remote-tracking ref, and an unexplained local/remote disagreement.
- [ ] The parent plan's own named cases are covered: a squash-merged bottom entry with descendants
      restacked whose diffs list only their own paths; the same with a foreign commit on the base
      whose line survives; a merge-commit parent detected by ancestry; a conflicting restack
      refused; no merged parent as a no-op; and `HEAD`, index, and status unchanged throughout.
- [ ] No task-number reference and no record-versioning phrase appears in either file under
      `agent-system/**`.
- [ ] `bash agent-system/extensions/core/scripts/verify-touched.sh` over the task's two declared
      paths exits 0 at each phase close.

## Artifacts & Outputs

- `agent-system/extensions/core/scripts/review-stack-prepare.sh` — the `restack` subcommand:
  `--merged NN` parsing, the dispatch arm, `rsp_restack_plan`, `rsp_restack_print`,
  `rsp_restack_execute`, the per-branch 49 guard, exit codes 53 and 54, the reconciled header
  `USAGE` and `EXIT CODES` blocks, and `show`'s `state` column.
- `agent-system/extensions/core/scripts/tests/test-review-stack-prepare.sh` — the restack cases,
  added alongside the existing 38 without editing any of them.
- The regenerated deployed `.claude/` tree (gitignored, not committed).
- `specs/691_restack_review_stack_when_parent_merges/summaries/01_*-summary.md` at completion.

## Rollback/Contingency

Both files are tracked under `agent-system/**` and every phase commits only its own hunks, so any
phase is revertible with `git revert` of that phase's commit, or by checking out the prior
revision of the two files specifically. Before beginning risky work in Phase 3, take a durable
checkpoint without reverting the working tree:
`bash .claude/scripts/git-snapshot.sh 691 --no-revert`.

If the touched-path check or the suite cannot be made green within the phase, mark the phase
`[PARTIAL]` with the failing case named and leave the prior phase's commit as the last green
state, rather than committing a red suite. If an existing assertion appears to require editing,
stop: per the dispatch's own instruction that is evidence the change is wrong, so revert the
offending edit and reconsider the approach rather than relaxing the assertion.

Two siblings are dispatched this same cycle on this same working tree (692 on
`milestone-review-handoff.sh` and its suite; 693 on `merge.md` and
`skill-git-workflow/SKILL.md`), all disjoint from this task's two files. Re-read each file
immediately before editing it, stage only this task's own hunks with an explicit file list, never
run `git-snapshot.sh` in its reverting default mode, and if a foreign commit or uncommitted
modification appears, stop and report it after checking `git log` rather than proceeding.
