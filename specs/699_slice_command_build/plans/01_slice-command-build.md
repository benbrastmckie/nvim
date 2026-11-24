# Implementation Plan: Task #699

- **Task**: 699 - slice_command_build
- **Status**: [IMPLEMENTING]
- **Effort**: 10 hours
- **Dependencies**: None (the ruling's "Successors" table, row 1: ordered after nothing)
- **Research Inputs**: specs/699_slice_command_build/reports/01_slice-command-build.md
- **Artifacts**: plans/01_slice-command-build.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md,
  source-store-deploy-boundary.md, no-task-references-in-deliverables.md,
  no-record-versioning-in-deliverables.md, pr-prohibition.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Build the one mechanism `specs/decisions/slice-command-one-path-to-review.md` keeps: a
user-invoked `/slice` command over one small script (`check`, `build`, `status`) and one series
file, with a suite that proves the two static constraints the ruling names. Every deliverable
lands in the core extension's source store (`agent-system/extensions/core/**`), is registered in
`manifest.json` / `suite-classification.data` / the extension `README.md`, and is then redeployed.
Definition of done for the *implementing agent*: suite green (including the static
no-push/no-forge assertion and the union check), `deploy-headless.sh` reporting a clean verify,
and the exact operator-typed lines printed — the record itself stays open until the operator has
pushed one slice and opened its pull request with `/slice`.

### Research Integration

The research report (`reports/01_slice-command-build.md`) establishes that the ruling is a
complete design and that no further design research is needed. Four of its findings are load
bearing here and are carried into the phases below:

- The overlay/commit/compare-and-swap primitive is written **fresh** in the new script. It must
  not `source`, call, or be refactored out of `scripts/review-stack-prepare.sh` — the ruling's
  "Basis" section rules no existing code is the basis, and that script is deleted by a sibling
  record ordered *after* this one, so depending on it would create an edge this record does not
  have.
- `rsp_move_commit_onto_new_parent`'s three-way `merge-tree` recompute is **not** ported:
  "Re-derive, never rebase" means a fresh overlay against the current base every time, never a
  moved tree.
- The `depends_on` cycle check is a bounded DFS validation over a small declared edge set, not
  the "inference code" ("no union-find, no topological sort, no overlap analysis") the ruling
  bans. No topological order is computed or persisted; `build` decides readiness per invocation
  from each slice's own `depends_on` states.
- `commands/merge.md` is the frontmatter model (`allowed-tools` with `AskUserQuestion` plus the
  forge CLI), `commands/tag.md` the model for the "user-invoked only, no agent/skill/lifecycle
  caller" restriction section.

### Premise Re-Validation (dispatch-extracted lines, checked at plan time)

Stated explicitly even where the check only confirms the description unchanged:

1. **"SOURCE STORE IS THE EDIT TARGET: `agent-system/extensions/core/**`"** — CONFIRMED live:
   `.claude-extensions.json`'s `.extensions.core.source_dir` resolves to
   `/home/benjamin/.config/nvim/agent-system/extensions/core`, and that directory exists. Every
   `Files to modify` entry below is a source-store path; no deployed `.claude/**` path is named
   anywhere in this plan.
2. **"`commands/slice.md` owns … the forge call lives here and nowhere else"** — CONFIRMED
   against the ruling's "The command surface" and "The mechanism" sections, re-read at plan time.
   The division of labour in those sections is reproduced in Phase 4's task list unchanged.
3. **"the shipped default (1,500 lines and 30 files, printed as `default, unmeasured`)"** —
   CONFIRMED against the ruling's "The size bar", bullet "Where the number comes from, in
   order", item (3), which gives exactly those two figures and exactly that label. The declared
   `slice_bar` key and the measured 75th-percentile path are excluded from this record, as the
   description states.
4. **Carried figure re-measured, not carried**: the research report records this repository as
   412 commits ahead of its remote default branch. Re-measured at plan time:
   `git rev-list --left-right --count origin/master...master` → `0  414` (0 behind, 414 ahead).
   The acceptance precondition ("a real difference exists to cut") holds, with a figure that has
   moved twice already — which is why no number of this kind appears in any deliverable.
5. **No collision**: `grep -rln 'slice_bar\|/slice\b' agent-system/` returns nothing, and
   `agent-system/extensions/core/commands/slice.md` does not exist. Re-confirmed at plan time.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No `roadmap_path` was provided in this dispatch and no roadmap flag is set; ROADMAP.md was not
consulted and is not written by this plan.

## Goals & Non-Goals

**Goals**:

- One script with exactly three subcommands (`check`, `build`, `status`) and no other entry
  point, containing no push, checkout, merge, or forge invocation.
- One series-file schema at `specs/.orchestration/slices/<series id>.json`, with the
  pull-request body beside it at `specs/.orchestration/slices/<series id>/<slice id>.md`.
- `commands/slice.md`: resolution, prompt 1, the bar line, prompt 2 with its four fixed lines and
  approve/revise/cancel, the per-slice typed push lines, the continue step, and the open step
  (the only place a forge call appears).
- A suite that asserts, statically, that the script contains no push/checkout/merge/forge
  invocation, and that verifies the union property (the target's tree overlaid with every slice
  equals the work ref's tree on every assigned path).
- Registration of all three new files, a clean redeploy, and an operator-facing handoff naming
  the exact lines to type.

**Non-Goals**:

- The declared `slice_bar` key and the measured 75th-percentile bar (a different record's
  territory). Only the shipped default, its label, the two accepted over-bar reasons, and
  revisability at prompt 2 are built here.
- Deleting `review-stack-prepare.sh` or its suite; narrowing `scripts/milestone-review-handoff.sh`;
  removing `commands/merge.md`; binding a push grant to the pushed ref
  (`hooks/please-grant.sh`, `hooks/guard-git-push.sh`, `scripts/lib/push-grant-lib.sh` — a
  sibling task's live territory this cycle); doc parity and the operator runbook.
- `merge-sources/claudemd.md` and `commands/README.md` rows for `/slice`. Nothing mechanical
  requires them (the doc lint's command sub-check reads the extension `README.md` only, which
  Phase 5 does update), and the generated CLAUDE.md command table belongs to the doc-parity
  successor. A slash command is discovered from the deployed `commands/` directory, so `/slice`
  is invocable after Phase 6 regardless.
- Any inference code: no union-find, no topological sort, no overlap analysis, no restack, no
  three-way merge, no conflict resolution.
- Repairing the pre-existing count drift in the extension `README.md`'s Overview table
  ("Commands | 16") and its "All 20 commands" sentence. Phase 5 adds a row and leaves both
  counts as they are; correcting them is the doc-parity successor's ground.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| The overlay primitive is "de-duplicated" by extracting it from `review-stack-prepare.sh` into a shared `lib/`, acquiring a dependency on a script a later-ordered record deletes | H | M | Phase 2 writes the primitive self-contained in the new script. Phase 3's suite asserts the script `source`s no review-stack file. Stated as a Decision below. |
| The implementing agent tries to satisfy the acceptance bar itself by pushing or opening a pull request | H | M | `rules/pr-prohibition.md` is absolute; the script carries no push/forge call and Phase 1's static assertion proves it. Phase 6 ends at printed operator instructions with the record NOT closed. |
| Scope creep into the five sibling records' territory | M | M | Every file this plan touches is enumerated per phase; none of the five excluded files appears in any `Files to modify` block. |
| A repo-specific name (branch, remote, consumer path) leaks into a deliverable | M | M | Suite fixtures name their remote and branch something that is neither a default remote name nor a default branch name, so a hardcoded assumption fails loudly instead of passing by accident; Phase 3 adds a static assertion over the script's own text for a literal remote/branch name. |
| Doc-lint Rule Q (undeclared script in source, not in `provides.scripts`) and the manifest-parity gate are knowingly red between Phase 1 and Phase 5 | L | H | Deliberate and bounded: no phase before 5 declares a tier that runs those gates, and Phase 5 closes them before the Phase 6 full gate. Recorded here so the red interval is not mistaken for a regression. |
| `check` is asked to validate a proposal before approval, but the series file must not be written before approval | M | M | Phase 1 gives `check` a candidate-document input (a path, or `-` for stdin) distinct from the durable series path, so prompt 2's counts come from a validation run that writes nothing. |
| A slice may not build or pass without its siblings; the union check does not prove it | M | H | Ruled as an accepted, unbuilt gap ("Risks", third item). Prompt 2 and every pull-request body state that no per-slice check ran. Phase 4 carries that sentence. |

## Decisions

1. **Script name**: `agent-system/extensions/core/scripts/slice-series.sh`, suite
   `agent-system/extensions/core/scripts/tests/test-slice-series.sh`. The script's unit of work
   is one series, and all three subcommands take a series document; the name follows the
   corpus's `subject-noun.sh` / `tests/test-<same>.sh` pairing, which is also what
   `suite_selection_select` resolves a touched script path by.
2. **`context/standards/orchestrator-runtime-files.md` gains a row** for
   `specs/.orchestration/slices/<series id>.json` and its sibling `<series id>/<slice id>.md`.
   The dispatch defers this decision to the plan; the decision is yes. That table is the single
   policy home for runtime-file disposition and the inventory a consumer repository reads when
   setting up its own ignore coverage, and a new durable-but-untracked state family with no row
   leaves it silently incomplete. The disposition is **Durable provenance, but untracked**,
   identical to the batch-record and queue-archive rows and covered by the pre-existing
   `**/.orchestration/` directory-class pattern in `scripts/lib/runtime-file-patterns.sh` — so
   **no new pattern member and no `.gitignore` change are required**, and
   `scripts/lib/runtime-file-patterns.sh` is deliberately not in this plan's territory.
   Consequence: that file and its coupled generated surface (`index-entries.json`'s `line_count`)
   join the territory in Phase 5.
3. **The extension `README.md` joins the territory.** `check-extension-docs.sh`'s
   README-vs-manifest command sub-check fails any command declared in `provides.commands` that
   is not mentioned in the extension's own `README.md`. Registering `slice.md` therefore
   mechanically requires a `README.md` row. This is a necessary consequence of the dispatch's
   own registration requirement, not doc-parity scope creep, and it is the one territory item
   the dispatch's Territory section does not name.
4. **The overlay primitive is written fresh**, with no `source` of and no shared-library
   extraction from `scripts/review-stack-prepare.sh` (the ruling's "Basis"; and that script is
   deleted by a record ordered after this one).
5. **`rsp_move_commit_onto_new_parent` is not ported.** A rebuild is a fresh overlay against the
   current base, never a moved tree; there is no three-way merge anywhere in the script.
6. **Refusal convention**: `REFUSED: slice-series.sh: <reason>: <message>` on stderr with a
   distinct named reason per refusal class and a script-specific exit code, never wrapped in a
   command substitution (an `exit` inside `"$(...)"` kills only the subshell). The exit-code
   numbering is settled in Phase 1 and pinned by the suite; it is a protocol detail, not a
   number asserted as a property of the system.
7. **No task-number reference and no record-versioning language** lands in any file under
   `agent-system/**` (both rules). Durable anchors only: filenames, section headings, the
   decision record's own title.

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2 | 1 |
| 3 | 3 | 2 |
| 4 | 4 | 3 |
| 5 | 5 | 4 |
| 6 | 6 | 5 |

Phases within the same wave can execute in parallel. This plan is fully sequential: each phase
consumes a contract the previous one fixes (the series schema, then the build primitive, then
`status`, then the command surface that names all three, then registration of files that must
exist on disk, then the redeploy of what was registered).

---

### Phase 1: Series Schema, Script Skeleton, `check`, and the Static Assertion [COMPLETED]

**Goal**: The series-file schema exists as a documented contract inside the script, the script
dispatches exactly three subcommands and refuses any other, `check` performs every validation the
ruling assigns it and prints the counts prompt 2 shows, and the suite's static
no-push/no-checkout/no-merge/no-forge assertion is written and passing before any other
acceptance criterion is checked.

**Tasks**:
- [x] Create `scripts/slice-series.sh` with `set -uo pipefail`, `SCRIPT_DIR` resolution,
      `lib/common.sh` sourcing, and the `deploy-root-guard.sh` sourcing convention the corpus's
      other `scripts/*.sh` members use. *(completed)*
- [x] Write the series-document schema as a header block: `series_id`; `target` (`remote`,
      `branch`, `commit` at last build); `work_ref` (`name`, `commit` at last build); `bar`
      (`lines`, `files`, `source` ∈ `declared` | `measured` (with `n`) | `default` |
      `chosen at prompt`); `not_landing` (path globs); and per slice `id`, `title`, `paths`
      (globs), `depends_on`, `over_bar_reason`, `state` ∈ `proposed` | `built` | `pushed` |
      `open` | `merged`, `ref`, `commit`, `base_commit`, `request_url`. Name the body file's
      location (`specs/.orchestration/slices/<series id>/<slice id>.md`) in the same block.
      *(completed)*
- [x] Implement subcommand dispatch for exactly `check`, `build`, `status`; any other argument
      (including none) is a named refusal, not a usage fallthrough into a default subcommand.
      *(completed)*
- [x] Give every subcommand a **candidate-document input** — a positional path, or `-` to read
      the series document from stdin — resolved separately from the durable
      `specs/.orchestration/slices/<series id>.json` path, so prompt 2's counts can come from a
      validation run that writes nothing. *(completed)*
- [x] Implement `check`: (a) the target is an ancestor of the work ref; (b) every path in the
      target→work-ref difference is in exactly one slice or matched by `not_landing`; (c) no
      declared glob matches nothing; (d) every `depends_on` entry names a declared slice and the
      edge set has no cycle (bounded DFS with a visited / in-progress marker, refusing on
      revisit — no persisted order, no component analysis); (e) every slice is at or under the
      bar or carries one of the two accepted reasons. *(completed: over_bar_reason enum settled
      as single_file|generated_tree, recorded as a deviation note in the progress file)*
- [x] Implement `check`'s count output: assigned-of-changed, unassigned, in-two-slices,
      not-landing (glob count plus "others"), the generated line ("none declared; every path
      counts toward the bar"), and the per-slice files / added-lines figures the proposal table
      prints. Added lines come from the first column of a `--numstat` difference over the
      slice's own paths; every path counts. *(completed)*
- [x] Implement the refusal convention from Decision 6, with one named reason and one exit code
      per refusal class above, and the comment explaining why a refusal resolver is never wrapped
      in a command substitution. *(completed)*
- [x] Create `scripts/tests/test-slice-series.sh` using the deployed-shape sandbox convention
      (`common_test_workdir_init`, an `install_scripts` helper copying the script under test,
      the whole `lib/` tree, and `deploy-root-guard.sh` into a `.claude/scripts/`-shaped fixture)
      and resolving its own roots via `common_test_repo_root` / `common_test_ext_root`, never a
      fixed-depth parent walk past the extension-root boundary. *(completed)*
- [x] Write the **static assertion first**: the script's non-comment lines contain no
      `git push`, `git checkout`, `git switch`, `git merge`, `git rebase`, `git replay`, `gh`, or
      `glab` invocation. This case must be written and passing before any later case is added.
      *(completed)*
- [x] Add `check` cases: one per refusal class, each with its expected named reason and exit
      code, plus a passing case asserting the printed counts. Fixture remotes and branches carry
      names that are neither a default remote name nor a default branch name. *(completed: 23
      cases, 0 failed)*

**Timing**: 2 hours

**Depends on**: none

**Verification Tier**: local

**Tier Justification**: `bash agent-system/extensions/core/scripts/verify-touched.sh` over this phase's two declared paths — run at plan-authoring time, `suite_selection_select` returns the `__FULL_SWEEP__` sentinel alone for them, because neither file exists yet and no other suite covers either path.

**Scope Hypothesis**: the sentinel measurement in the line above is a fact about the tree as it
stands before this phase runs; the hypothesis is that once this phase's own suite lands,
`suite_selection_select` resolves the script path to that suite's basename (the shape the
existing `scripts/review-stack-prepare.sh` / `scripts/tests/test-review-stack-prepare.sh` pair
already produces). Confirm by re-running the selector over both paths at the end of this phase
and running the new suite directly; the sentinel is not re-claimed in later phases.

**Files to modify**:
- `agent-system/extensions/core/scripts/slice-series.sh` - new: schema header, subcommand
  dispatch, candidate-document input, `check`, refusal convention
- `agent-system/extensions/core/scripts/tests/test-slice-series.sh` - new: static
  no-push/no-forge assertion plus the `check` refusal and count cases

**Verification**:
- `bash agent-system/extensions/core/scripts/tests/test-slice-series.sh` exits 0 with the static
  assertion case among the passes.
- `bash agent-system/extensions/core/scripts/verify-touched.sh` over this phase's two paths
  reports its narrowed verdict without failure.
- `bash agent-system/extensions/core/scripts/lint/lint-shellcheck.sh` (or the gate-22 entry point
  it is reached by) reports no finding for the two new files.
- Invoking the script with an unknown subcommand, and with none, each produces the named refusal
  and its exit code, not a default-subcommand fallthrough.

---

### Phase 2: `build` — Private Index, Overlay, `write-tree`, `commit-tree`, Compare-and-Swap [COMPLETED]

**Goal**: `build` turns an approved series document into one commit per buildable slice and moves
each `refs/heads/slice/<series>/<id>` by compare-and-swap, with `HEAD`, the shared index, and the
working tree untouched, refusing everything `check` refuses.

**Tasks**:
- [x] Implement the overlay primitive, written fresh and self-contained: a private
      `GIT_INDEX_FILE` (a `mktemp` file removed immediately after `write-tree`), `read-tree` of
      the base tree, then per declared path either `update-index --cacheinfo` with that path's
      mode and object id at the work ref, or `update-index --force-remove` for a path the work
      ref deletes. No `source` of and no extraction from `scripts/review-stack-prepare.sh`.
      *(completed)*
- [x] Compute each slice's base: the target's tip overlaid with the slices in its dependency
      closure. Compute its parent: the target's tip, or the one unmerged dependency's commit.
      *(completed)*
- [x] Implement the waiting rule: a slice with two or more unmerged dependencies is not built and
      is reported as waiting, so no slice commit ever has two parents. *(completed)*
- [x] `write-tree`, then `commit-tree <tree> -p <parent>` with the slice's title and body.
      *(completed: commit message is the slice title; the schema has no separate commit-message
      body field)*
- [x] Move the ref by three-argument `git update-ref <ref> <new> <old>`, refusing (never silently
      overwriting) when the compare-and-swap fails because the ref moved concurrently.
      *(completed)*
- [x] Re-derive, never rebase: a rebuild of an already-built slice is a fresh overlay against the
      current base, with no three-way merge and no conflict resolution anywhere in the path.
      *(completed)*
- [x] Write the slice's pull-request body to
      `specs/.orchestration/slices/<series id>/<slice id>.md` if absent, leaving an existing body
      untouched (it is editable until the request is opened), and record `commit`, `base_commit`,
      `ref`, and `state` back into the series document. *(completed)*
- [x] Assert `build` refuses every slice `check` refuses, by routing `build` through the same
      validation entry point rather than duplicating the checks. *(completed: build calls the
      same ss_check_ancestor/ss_check_assignment_and_globs/ss_check_depends_on/ss_check_bar
      functions check uses; one representative case (depends_on_cycle) pins the routing)*
- [x] Suite cases: a one-slice build; an independent two-slice build; a dependent slice built on
      its one unmerged dependency's commit; a slice with two unmerged dependencies reported as
      waiting and not built; a path the work ref deletes; a compare-and-swap refusal when the ref
      moved; and an assertion after every build case that `HEAD`, the shared index, and the
      working tree are byte-identical to their pre-build state. *(completed: 13 new cases, 36
      total passing; deviation -- the untouched-state assertion compares HEAD, the shared
      index's tracked content, and `git diff` over tracked paths rather than raw `git status
      --porcelain`, since build's own required series-document and pull-request-body writes are
      new untracked paths that raw `git status --porcelain` would flag as a change; see progress
      file deviation 2.9)*

**Timing**: 2 hours

**Depends on**: 1

**Verification Tier**: local

**Tier Justification**: `bash agent-system/extensions/core/scripts/verify-touched.sh` over this phase's two declared paths — the narrowed pass over the one script and the one suite this phase edits; measured at plan-authoring time the selector returns the `__FULL_SWEEP__` sentinel alone for them, since neither file exists yet.

**Scope Hypothesis**: the sentinel above is measured against the pre-Phase-1 tree; once this
task's own suite (`scripts/tests/test-slice-series.sh`) exists it is the one suite covering both
paths. Confirm by re-running the selector over both paths at the start of this phase and running
that suite directly.

**Files to modify**:
- `agent-system/extensions/core/scripts/slice-series.sh` - add the `build` subcommand, its overlay/commit/compare-and-swap primitive, and its base/parent resolution
- `agent-system/extensions/core/scripts/tests/test-slice-series.sh` - add the `build` cases and the untouched-HEAD/index/worktree assertions

**Verification**:
- `bash agent-system/extensions/core/scripts/tests/test-slice-series.sh` exits 0 with every new
  `build` case among the passes, the static assertion still passing.
- After each build case the fixture's `HEAD`, `git status --porcelain`, and `git diff --cached`
  are unchanged from their pre-build values.
- A fixture whose slice ref moved between read and write produces the compare-and-swap refusal,
  not an overwrite.
- `bash agent-system/extensions/core/scripts/verify-touched.sh` over this phase's two paths
  reports its narrowed verdict without failure.

---

### Phase 3: `status`, the Union Check, and the Repo-Agnosticism Assertion [COMPLETED]

**Goal**: `status` reports, per slice, the local ref and the remote ref against the recorded
commit plus the content-based merged test; the suite proves the union property; and the suite
proves statically that the script hardcodes no remote or branch name and depends on no
review-stack file.

**Tasks**:
- [x] Implement `status`: per slice, the local ref against the recorded commit, the remote
      tracking ref against the recorded commit, and the merged test — the slice's own paths at
      the target's tip equal the slice's content, so a squash merge is recognised. A content
      test, never a commit-ancestry test. *(completed)*
- [x] Have `status` report the state vocabulary already in the schema (`proposed`, `built`,
      `pushed`, `open`, `merged`) and name, for an unmerged slice whose base has moved, that a
      rebuild is due — printing the fact, performing no push and no merge. *(completed)*
- [x] Add the union check to the suite: the target's tree overlaid with every built slice equals
      the work ref's tree on every assigned path. Compare resolved tree content over the assigned
      path set, not a commit range. *(completed)*
- [x] Add the repo-agnosticism static assertion: the script's text contains no literal default
      remote name and no literal default branch name. *(completed)*
- [x] Add a static assertion that the script neither `source`s nor invokes
      `review-stack-prepare.sh` nor any other script outside `lib/` and `deploy-root-guard.sh`.
      *(completed: deviation -- excludes pure-comment lines from the review-stack-prepare grep,
      since the script's own explanatory comment names the decision not to depend on it; see
      progress file deviation 3.5)*
- [x] Add `status` cases: a built-but-unpushed slice; a pushed slice whose remote ref matches;
      a pushed slice whose remote ref diverges from the recorded commit; a slice merged by squash
      (recognised by content); and an unmerged slice whose base has moved. *(completed: 9 new
      cases, 45 total passing; deviation -- the "pushed" fixtures fabricate the resulting
      refs/remotes/<remote>/... ref directly via `git update-ref` rather than `git push`, which
      this environment's guard hook blocks unconditionally even against a throwaway local
      fixture remote; see progress file deviation 3.1)*

**Timing**: 1.5 hours

**Depends on**: 2

**Verification Tier**: local

**Tier Justification**: `bash agent-system/extensions/core/scripts/verify-touched.sh` over this phase's two declared paths — the same narrowed pass over the one script and the one suite this phase edits; measured at plan-authoring time the selector returns the `__FULL_SWEEP__` sentinel alone for them, since neither file exists yet.

**Scope Hypothesis**: as in the preceding phase, the sentinel is measured against the
pre-Phase-1 tree; once this task's own suite exists it is the one suite covering both paths.
Confirm by re-running the selector over both paths at the start of this phase.

**Files to modify**:
- `agent-system/extensions/core/scripts/slice-series.sh` - add the `status` subcommand and its
  content-based merged test
- `agent-system/extensions/core/scripts/tests/test-slice-series.sh` - add the union check, the
  two further static assertions, and the `status` cases

**Verification**:
- `bash agent-system/extensions/core/scripts/tests/test-slice-series.sh` exits 0 with the union
  check and all three static assertions among the passes.
- A fixture in which one slice's paths were squash-merged onto the target is reported `merged` by
  the content test.
- `grep` over the script for a literal default remote or branch name returns nothing (the
  assertion's own mechanism, run directly as a cross-check).
- `bash agent-system/extensions/core/scripts/verify-touched.sh` over this phase's two paths
  reports its narrowed verdict without failure.

---

### Phase 4: `commands/slice.md` — The Command Surface [NOT STARTED]

**Goal**: One command file owning everything the script must not: resolution, prompt 1, the bar
line, prompt 2, the per-slice typed push lines, the continue step, and the open step — the one
and only place a forge call appears.

**Tasks**:
- [ ] Create `commands/slice.md` with `commands/merge.md`'s frontmatter shape: a `description`,
      an `argument-hint` for the optional free-text description, and `allowed-tools` naming
      `AskUserQuestion`, the git and forge CLI surfaces, and the new script's invocation.
- [ ] Carry `commands/tag.md`'s restriction framing: user-invoked only; no agent, skill, or
      lifecycle script invokes it; state the `rules/pr-prohibition.md` boundary explicitly.
- [ ] **Resolution** (printed, no question): work ref and short sha; the remote (the branch's
      configured remote, else the only remote; asked only when the branch has none configured and
      there is more than one); fetch freshness, including the "figures are against the last
      fetch" line on failure; and the uncommitted-paths line when the tree is dirty. A repository
      with no remote stops with one line.
- [ ] **Prompt 1 (the target)**: one question, each candidate carrying its measured difference
      from the work ref. Candidate set: an in-flight series for this work ref shown first as
      `continue`, the remote's default branch, the bases of the user's own open requests on that
      remote where they differ, and free entry always last. A candidate that is not an ancestor
      of the work ref is shown and cannot be chosen, with the merge-up named. A candidate whose
      difference is empty is shown as `nothing to slice`. An equal name is never itself a reason
      to refuse.
- [ ] **The bar line** (printed, no question): lines and files with the source label. This record
      ships only the default — 1,500 lines and 30 files, printed as `default, unmeasured`.
- [ ] **Prompt 2 (the proposal)**: the table (id, title, files, lines / bar, depends on, opens
      against, with `OVER: <reason>` and `OVER, NO REASON`), the four fixed lines always printed
      with zeros shown as zeros (assigned / unassigned / in-two-slices; not landing; generated
      "none declared; every path counts toward the bar"; cost), the sentence that no per-slice
      check ran, and `approve / revise / cancel`. The proposal is made by the command's model from
      the difference, the directory structure, and completed tasks' `modified_files` as a hint
      only. Revise takes free text and re-proposes, including replacing the bar (recorded as
      `chosen at prompt`). **Nothing is written before approve.**
- [ ] State that the counts shown at prompt 2 come from a `check` run over a candidate series
      document that is not the durable series path, so the prompt writes nothing.
- [ ] **On approval**: write the series file and the pull-request bodies, run `build`, verify the
      union, then print one line per slice — the built short sha and the exact
      `/please push <remote> slice/<series>/<id>` line to type, `waits on <id>` for a waiting
      slice, `not built: over the bar with no reason` for a refused one — and the closing
      `then: /slice`.
- [ ] **The continue step** of a later invocation: one state line per slice from `status`, then
      one question listing only what is due — the request to open (base, head, title; opened on
      "yes" and its URL recorded in the series file); the content-based merged marking; the
      rebuild of an unmerged slice whose base has moved, with the push line printed again (plain
      if never pushed, `--force-with-lease` if it was); and, when the target is not an ancestor of
      the work ref, one line naming the merge-up needed and nothing else.
- [ ] **The open step**: the forge call, here and nowhere else, with the request URL recorded in
      the series file afterward.
- [ ] State the visible-stack option (allowed when asked for in revise) and its cost line, and
      "Re-derive, never rebase": no restack, no three-way merge, no conflict resolution.
- [ ] State "one invocation, one target": work bound for a second target is a second series.
- [ ] Carry no branch name, no remote name, no consumer path, and no task-number or
      record-versioning language anywhere in the file.

**Timing**: 2 hours

**Depends on**: 3

**Verification Tier**: local

**Tier Justification**: `bash agent-system/extensions/core/scripts/verify-touched.sh agent-system/extensions/core/commands/slice.md` plus, for this source-store markdown path, `bash /home/benjamin/.config/nvim/.claude/scripts/verify-deploy.sh --skip-slow --only-gate 3,4 /home/benjamin/.config/nvim`; the selector returns the `__FULL_SWEEP__` sentinel alone for this phase's one path, so no suite covers it and the doc-lint/task-reference gate subset is the covering check.

**Files to modify**:
- `agent-system/extensions/core/commands/slice.md` - new: the whole command surface (resolution,
  both prompts, the bar line, the push lines, the continue step, the open step)

**Verification**:
- `bash /home/benjamin/.config/nvim/.claude/scripts/verify-deploy.sh --skip-slow --only-gate 3,4 /home/benjamin/.config/nvim`
  reports no failure attributable to the new file. (Gate 3's README-vs-manifest command
  sub-check cannot fire yet — the manifest entry lands in Phase 5 — so its clean result here is
  not evidence for that sub-check; Phase 5 re-runs it.)
- `grep -nE 'task [0-9]|\(task [0-9]' agent-system/extensions/core/commands/slice.md` returns
  nothing, and a read-through finds no version-lineage phrasing.
- A read-through confirms every element of the ruling's "The command surface" steps 1-6 is
  present, including the four fixed lines under the proposal table and the no-per-slice-check
  sentence.
- `grep` over the file for a literal default remote or branch name returns nothing.
- Diff read-through confirming every changed hunk lies inside the one new file.

---

### Phase 5: Registration and the Runtime-File Row [NOT STARTED]

**Goal**: The three new files are declared everywhere the deploy and its gates require, and the
series file earns its row in the runtime-file policy table with its coupled generated surface
reconciled in the same phase.

**Tasks**:
- [ ] Add `scripts/slice-series.sh` and `scripts/tests/test-slice-series.sh` to
      `manifest.json`'s `provides.scripts`, at the alphabetically correct positions (beside the
      existing `review-stack-prepare.sh` / `tests/test-review-stack-prepare.sh` entries as the
      naming and placement precedent).
- [ ] Add `"slice.md"` to `manifest.json`'s `provides.commands`.
- [ ] Add the suite's row to `scripts/tests/suite-classification.data`: TAB-separated
      `test-slice-series.sh`, class `unit`, reason `-`. The suite must therefore spawn none of
      `deploy-headless.sh`, `verify-deploy.sh`, or a nested `run-all.sh` — confirm before writing
      the row rather than after.
- [ ] Add a `/slice` row to the extension `README.md`'s Commands table (mechanically required:
      the doc lint fails a `provides.commands` entry not mentioned there). Leave the Overview
      table's count and the "All 20 commands" sentence untouched.
- [ ] Add one row to `context/standards/orchestrator-runtime-files.md` for
      `specs/.orchestration/slices/<series id>.json` and its sibling
      `<series id>/<slice id>.md`: writer, reader, cleanup, and the **Durable provenance, but
      untracked** disposition, stating that it is covered by the pre-existing
      `**/.orchestration/` directory-class pattern so no new pattern member is needed. Place it
      beside the batch-record / queue-archive / review-manifest rows that share that disposition.
      Do not touch the review-manifest row — its deletion belongs to a different record.
- [ ] Regenerate the coupled line-count surface in the same phase:
      `bash agent-system/extensions/core/scripts/generate-context-line-counts.sh --write`, which
      updates `index-entries.json`'s `line_count` for
      `standards/orchestrator-runtime-files.md` (its declared value before this phase is the
      pre-edit length, which the doc lint's line-count rule checks).
- [ ] Confirm, before closing the phase, that the correction target named above still exists:
      `context/standards/orchestrator-runtime-files.md` and its `index-entries.json` entry were
      both confirmed present at plan time. If either is absent when this phase runs, add the row
      to whichever file then holds the runtime-file inventory and record the deviation rather
      than inventing a target.

**Timing**: 1 hour

**Depends on**: 4

**Verification Tier**: full

**Tier Justification**: `manifest.json` is global deploy configuration whose entries drive the whole-tree category-parity and content-hash gate, `suite-classification.data` governs the merged deployed tests directory shared by every extension, and `index-entries.json` is the deploy-wide context index — cross-cutting registration surfaces that no single-module or one-hop-dependent check covers.

**Scope Hypothesis**: this phase asserts four registration edits (two `provides.scripts` entries,
one `provides.commands` entry, one `suite-classification.data` row), one `README.md` row, and one
runtime-file table row — six edits across five files plus the regenerated `index-entries.json`.
Confirm at implementation time by re-running the doc lint and the manifest-parity gate and
reading their findings: an additional required registration site surfacing there is a correction
to this estimate, not a reason to skip it.

**Files to modify**:
- `agent-system/extensions/core/manifest.json` - two script entries plus the one command entry
- `agent-system/extensions/core/scripts/tests/suite-classification.data` - one unit-class row for the new suite
- `agent-system/extensions/core/README.md` - one `/slice` row in the Commands table
- `agent-system/extensions/core/context/standards/orchestrator-runtime-files.md` - one row for the series file and its sibling body file
- `agent-system/extensions/core/index-entries.json` - regenerated line count for the edited standards file (coupled generated surface of the row above)

**Verification**:
- `bash /home/benjamin/.config/nvim/.claude/scripts/verify-touched.sh` over this phase's five
  paths reports its narrowed verdict without failure. The complete gate set is deferred to the
  orchestration close, per the batch-gate stage, and is not independently invoked here.
- `python3 -c "import json; json.load(open('agent-system/extensions/core/manifest.json'))"`
  succeeds, and the three new entries are present exactly once each.
- `bash agent-system/extensions/core/scripts/lint/lint-unit-integration-boundary.sh` reports the
  new suite classified, with no unclassified-suite failure.
- The doc lint's README-vs-manifest command sub-check passes for `/slice` (it could not fire
  before this phase, since the manifest entry did not exist).
- `index-entries.json`'s `line_count` for `standards/orchestrator-runtime-files.md` equals that
  file's actual length after the edit.

---

### Phase 6: Redeploy, Full Verification, and the Operator Handoff [NOT STARTED]

**Goal**: The registered deliverables are deployed and verified clean, and the dispatch returns
with the record **not** closed, naming the exact lines the operator types to push one slice and
open its pull request.

**Tasks**:
- [ ] Redeploy with the bounded-wait idiom:
      `timeout 540 bash agent-system/extensions/core/scripts/deploy-headless.sh /home/benjamin/.config/nvim`
      with the Bash tool timeout set to 600000. Treat exit 3 (deploy landed, inline verify
      reported failures) and exit 4 (verify suppressed) as distinct from exit 0 — neither is a
      clean verify.
- [ ] Confirm the deploy landed the three new files: `.claude/commands/slice.md`,
      `.claude/scripts/slice-series.sh`, `.claude/scripts/tests/test-slice-series.sh`.
- [ ] Run the new suite from the deployed tree as well as the source store, so the
      deployed-shape fixture convention is exercised from both invocation paths.
- [ ] Run the scoped touched-path check over every path this task touched, and record that the
      complete gate set is deferred to the orchestration close rather than independently invoked
      here.
- [ ] Do a dry read-through of `/slice`'s own resolution and prompt-1 arithmetic against this
      repository's live difference — printing only, writing nothing, pushing nothing — to confirm
      the command's figures resolve against a real difference.
- [ ] Record, in the dispatch's own return and handoff, the exact operator lines: for each slice
      the `/please push <remote> slice/<series>/<id>` line, then `/slice` to open the requests.
      State plainly that an agent can neither push nor open a pull request
      (`rules/pr-prohibition.md`), so the record stays open until the operator has done both and
      the request URL is recorded in the series file.
- [ ] Do not mark the task complete, do not push, do not invoke a forge CLI, and do not create a
      pull request.

**Timing**: 1.5 hours

**Depends on**: 5

**Verification Tier**: full

**Files to modify**:
- `__WHOLE_TREE__` - this phase invokes whole-tree regeneration via `deploy-headless.sh`
- `agent-system/extensions/core/index-entries.json` - any residual line-count repair the deploy
  performs as a side effect of regeneration

**Verification**:
- `timeout 540 bash agent-system/extensions/core/scripts/deploy-headless.sh /home/benjamin/.config/nvim`
  exits 0 — a clean deploy *and* a clean inline verification. Exit 3 or 4 is a failure of this
  criterion, not a pass.
- `bash .claude/scripts/verify-touched.sh` over every path this task touched reports its narrowed
  verdict without failure; the complete gate set is **deferred to the orchestration close** (the
  once-per-invocation batch gate stage), not independently invoked by this phase.
- `bash .claude/scripts/tests/test-slice-series.sh` and
  `bash agent-system/extensions/core/scripts/tests/test-slice-series.sh` both exit 0.
- The three deployed files exist and are non-empty.
- The handoff and the final return each name the operator lines verbatim and state that the
  record is not closed.

---

## Testing & Validation

- [ ] The static assertion: the script's non-comment text contains no `git push`,
      `git checkout`, `git switch`, `git merge`, `git rebase`, `git replay`, `gh`, or `glab`
      invocation.
- [ ] The repo-agnosticism assertion: no literal default remote name and no literal default
      branch name in the script, and none in `commands/slice.md`.
- [ ] The no-dependency assertion: the script neither `source`s nor invokes
      `review-stack-prepare.sh`.
- [ ] The union check: the target's tree overlaid with every built slice equals the work ref's
      tree on every assigned path.
- [ ] Every `check` refusal class has a case pinning its named reason and exit code.
- [ ] `build` leaves `HEAD`, the shared index, and the working tree unchanged in every case.
- [ ] A slice with two or more unmerged dependencies waits; no slice commit has two parents.
- [ ] A compare-and-swap failure refuses rather than overwriting.
- [ ] `status`'s merged test recognises a squash merge by content.
- [ ] `deploy-headless.sh` exits 0 (clean deploy and clean inline verify).
- [ ] The new suite passes from both the source store and the deployed tree.
- [ ] No file under `agent-system/**` carries a task-number reference or record-versioning
      language.

## Artifacts & Outputs

- `agent-system/extensions/core/scripts/slice-series.sh` (new)
- `agent-system/extensions/core/scripts/tests/test-slice-series.sh` (new)
- `agent-system/extensions/core/commands/slice.md` (new)
- `agent-system/extensions/core/manifest.json` (three entries added)
- `agent-system/extensions/core/scripts/tests/suite-classification.data` (one row added)
- `agent-system/extensions/core/README.md` (one Commands row added)
- `agent-system/extensions/core/context/standards/orchestrator-runtime-files.md` (one row added)
- `agent-system/extensions/core/index-entries.json` (regenerated line count)
- The redeployed `.claude/` tree
- A summary artifact naming the exact operator-typed lines, with the record left open

## Rollback/Contingency

Each phase is independently revertible: Phases 1-3 touch only two new files, Phase 4 only one
new file, and Phase 5 only additive entries and rows that can be removed exactly as they were
added. Nothing in this plan mutates `HEAD`, the index, or any existing script's behaviour, so a
revert needs no ref surgery.

If the working tree must be rolled back before a destructive step, take the snapshot first using
the rollback-rung invocation shape in `context/contracts/recovery.md` (including its
out-of-scope override flag for a deliberate whole-tree case) rather than a bare precautionary
checkpoint; for an ordinary defensive checkpoint before risky work, the non-reverting
`--no-revert` mode is the right call.

Contingency by phase:

- A `build` primitive that cannot be made to leave `HEAD`/index/worktree untouched is a stop
  point, not a thing to work around: report it rather than relaxing the assertion.
- If the deploy's inline verification reports a failure attributable to registration, repair the
  registration and redeploy; do not pass `--skip-verify` to reach a green-looking exit.
- If the dry read-through of prompt 1 shows the arithmetic cannot resolve against this
  repository's live difference, stop and report — the acceptance bar is one real slice of a real
  difference, and a command whose figures do not resolve cannot reach it.
