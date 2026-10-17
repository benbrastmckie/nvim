# Implementation Summary: Task #362

- **Task**: 362 - Teach the non-destructive history-read techniques at the point of use, so an implementation agent inspecting past file state never reverts a shared working tree
- **Status**: [COMPLETED]
- **Started**: 2026-10-17T00:00:00Z
- **Completed**: 2026-10-17T02:00:00Z
- **Effort**: ~2.5 hours
- **Dependencies**: 356, 359 (both confirmed complete at plan time)
- **Artifacts**: plans/01_shared-worktree-discipline.md, summaries/01_shared-worktree-discipline-summary.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md

## Overview

Authored one new standards page, `context/standards/shared-worktree-discipline.md`, in the core
extension source store, naming the read-only history-inspection techniques (`git show`, `git
diff`, scratchpad copy) and the three forbidden tree-reverting commands (`git stash`, `git
checkout -- <path>`, `git restore <path>`). Made it reachable with a short, literal MUST NOT
bullet citing it by path in the Critical Requirements list of all 15 in-scope implementation
agent definitions (the core agent plus 14 extension agents) and in the agent template, so future
generated implementation agents inherit the pointer by construction. Registered the page in the
core extension's `index-entries.json`, added a one-line cross-reference from `git-safety.md`,
redeployed, and demonstrated the pointer chain on the deployed tree with a reproducible grep.

## What Changed

- `agent-system/extensions/core/context/standards/shared-worktree-discipline.md` — new page (61
  lines): why parallel dispatches share one tree; read-history and read-diff commands; a
  scratchpad-copy instruction for mutable experiments; the three forbidden commands with one
  clause each; the detached-worktree technique labelled explicitly as a READ-ONLY INSPECTION
  TECHNIQUE, never an isolation strategy; a `## Placement` section recording both rejected
  placements; a closing pointer to `git-workflow-narrative.md`'s incident section.
- `agent-system/extensions/core/index-entries.json` — one entry added for the new page, with
  `load_when.agents` enumerating all 15 in-scope implementation agent names (not the
  single-agent precedent form).
- `agent-system/extensions/core/context/standards/git-safety.md` — one cross-reference line
  added at the end of its "A Second Hazard Class" section, pointing at the new page.
- `agent-system/extensions/core/agents/general-implementation-agent.md` — Critical Requirements
  MUST NOT list item 16 added (the canonical bullet).
- `agent-system/extensions/core/context/templates/agent-template.md` — one forward-looking
  variant bullet added, sibling to the existing bounded-wait bullet.
- 14 extension implementation agent definitions (books, books-hard, cslib, cslib-hard,
  pr-review, email, latex, nix, neovim, python, rust, typst, web, z3) — the same canonical
  bullet appended verbatim (apart from its leading number) to each file's Critical Requirements
  MUST NOT list, in one atomic-batch commit.
- The two Lean implementation agent definitions were deliberately **not** touched (see Scope
  Boundary below).

## Decisions

- **Placement**: both candidate documents named in the dispatch (`git-safety.md`,
  `git-workflow-narrative.md`) were surveyed in full and rejected. `git-safety.md` is a
  before/during risky-operation safety-commit/rollback playbook with no natural home for
  point-of-use read-only guidance, and no implementation agent definition referenced it at all
  before this task, so amending it alone would not have improved reachability.
  `git-workflow-narrative.md` is a lazily-loaded reactive elaboration, read only once an agent is
  already following the core rules — the opposite of findable at the moment a git command is
  chosen. A new standalone page was created instead, mirroring the structure and `## Placement`
  pattern of the existing `context/standards/post-incident-verification-checklist.md`, which
  faced an identical placement question for closely analogous content. Net new document count:
  exactly one.
- **`load_when.agents` choice**: the new index entry enumerates all 15 in-scope implementation
  agent names rather than reusing the single-agent precedent form, because this task's own scope
  is all 15 and a one-agent registration would have reproduced, in the index itself, the same
  discoverability gap this task exists to close.
- **Cross-reference location in `git-safety.md`**: placed at the end of the "A Second Hazard
  Class: Rewriting Already-Committed History Under Concurrent Writers" section rather than the
  file's thin "## References" list, because that list is about command/subagent-structure docs
  unrelated to git-workflow content, while the hazard-class section is the closest existing
  discussion of concurrent-writer git hazards in the file.
- **Carried-figure disposition**: the two-agent bare-`git stash` incident count was re-confirmed
  against `context/standards/git-workflow-narrative.md`'s own incident section (exact match: "two
  independent implementation agents each ran a bare, whole-tree `git stash`"). The
  detached-worktree planner instance and the `git show <stash-ref>:path` self-recovery instance
  are **not re-derivable from this repository** (no hits for either anywhere under
  `agent-system/extensions/core/`) — the originating batch ran in a separate consumer
  repository. Both are treated as illustrative only; the new page does not cite either as a
  confirmed fact, and its required content does not depend on them.

## Plan Deviations

- A mechanical slip in Phase 3, caught and corrected within the same phase: the first pass of
  appending the canonical bullet to the 14 extension agent files (via `printf` with a leading
  newline) introduced a stray blank line before each new item, inconsistent with the existing
  MUST NOT lists' no-blank-line-between-items convention. Corrected with a targeted
  `perl -0777 -pi` substitution removing exactly that blank line in each of the 14 files, before
  any verification ran. No other deviation from the plan.

## Verification

- Build: N/A (documentation/agent-definition task)
- Tests: N/A (no test suite covers pure-guidance markdown or agent-contract additions; covered
  by lint gates instead)
- Files verified: Yes

### Per-phase gate results

- **Phase 1** (`verify-deploy.sh --skip-slow --only-gate 3,4`): doc-lint and task-reference lint
  both PASS. `generate-context-line-counts.sh --check` initially found `git-safety.md`'s own
  declared `line_count` stale (705 vs. actual 708) after the one-line cross-reference edit;
  fixed via `--write`, then re-checked clean.
- **Phase 2** (`verify-deploy.sh --skip-slow --only-gate 3,4,6`): doc-lint, task-reference lint,
  and agent-contracts lint all PASS. `generate-context-line-counts.sh --check` similarly found
  `agent-template.md` stale (123 vs. 127) after the bullet addition; fixed via `--write`.
- **Phase 3** (`verify-deploy.sh --skip-slow --only-gate 3,4,6`): all three gates PASS.
  `generate-context-line-counts.sh --check` reported 0 changes (agent definitions under
  `agents/` are not tracked by `index-entries.json`). `grep -l "shared-worktree-discipline"
  agent-system/extensions/*/agents/*implementation*.md | wc -l` reports 15 (14 propagated in
  this phase plus the core agent from Phase 2); the two Lean agent files are confirmed absent
  from that grep.
- **Phase 4**: redeployed via `deploy-headless.sh` (`RESULT=landed_verify_clean`, 36 fast-gate
  checks passing). `check-deploy-freshness.sh` exits 0. `test -f
  .claude/context/standards/shared-worktree-discipline.md` and `grep -c shared-worktree-discipline
  .claude/context/index.json` (= 1) confirm the new page landed in the deployed tree.
  `check-task-references.sh` reports 0 unexempted occurrences repo-wide (excluding `specs/**`).
  `generate-context-line-counts.sh --check` passes clean (583/583 exact).

### Batch Gate Deferral honored

This dispatch's own dispatch file (`.dispatch/24.md`) carried a `## Batch Gate Deferral`
directive naming this task as one of several `implement`-phase dispatches inside one multi-task
`/orchestrate` batch invocation. Per that directive, Phase 4 (declared `**Verification Tier**:
full` in the plan — left unedited) was discharged against the scoped-tier narrowing instead of
independently running the complete, unscoped `verify-deploy.sh` gate set:
`bash agent-system/extensions/core/scripts/verify-deploy.sh --skip-slow --only-gate 3,4,6
/home/benjamin/.config/nvim`, re-run one final time against the freshly redeployed tree — doc-lint,
task-reference lint, and agent-contracts lint (the three gates relevant to every file this task
touched across all four phases) all PASS. The complete, unscoped 23-gate set is deferred to the
once-per-invocation batch-level stage at the end of this `/orchestrate` run, not independently
run here, per `context/formats/plan-format.md`'s "Batch-aware deferral" subsection — this is
stated explicitly rather than silently narrowed, as the plan's own Phase 4 verification
instructions require.

### Reachability demonstration (reproduced, not merely asserted)

````
$ grep -n "shared-worktree-discipline" .claude/agents/general-implementation-agent.md
1032:    mutable file -- see `context/standards/shared-worktree-discipline.md`.

$ sed -n '/^## Read history/,/^## Detached worktree/p' .claude/context/standards/shared-worktree-discipline.md
## Read history

```bash
git show HEAD:path/to/file      # file content as of HEAD
git show <ref>:path/to/file     # file content as of any other commit/ref
```

## Read differences

```bash
git diff HEAD -- path/to/file
```

## Mutable copy

If an experiment genuinely needs a writable copy of historical content, extract it to the
session scratchpad directory (the path the environment block names) -- never materialize it back
into the shared tree.

## Never, on a shared tree

- `git stash` (bare or whole-tree) -- reverts every uncommitted path to HEAD, not just the one
  under inspection, out from under concurrent writers.
- `git checkout -- <path>` -- discards the path's uncommitted content in place, with no entry to
  recover it from.
- `git restore <path>` (without `--staged`) -- the same discard, under `restore`'s newer name.

Each of these reverts the tree out from under concurrent writers, who share this one working
tree by design.

## Detached worktree -- READ-ONLY INSPECTION TECHNIQUE, not an isolation strategy
````

Note: the plan's suggested demonstration command (`sed -n '/Read history with/,/shared-worktree-discipline/p'`)
assumed inline prose reading "Read history with"; this page instead uses a `## Read history`
heading, so the sed pattern above was adapted to the page's actual structure while preserving the
demonstration's intent — a cited path from a deployed agent definition to the deployed page's
substantive content, reproducible by any reader.

Secondary observation (not a defect): only 6 implementation agent definitions are deployed into
this repository's `.claude/` tree (email, general, lean, lean-hard, neovim, nix — the other
extensions this task's `file_scope` names, such as books/cslib/latex/python/rust/typst/web/z3,
are not loaded via this repository's `.claude-extensions.json`). Of the 6 deployed, the 4
non-Lean ones (email, general, neovim, nix) all carry the pointer; the 2 Lean ones correctly do
not. The remaining 8 of the 14 propagated-to agent files exist and carry the pointer in the
**source store** (confirmed earlier at 15/15 via
`grep -l "shared-worktree-discipline" agent-system/extensions/*/agents/*implementation*.md`) and
will appear in any `.claude/` tree that loads those extensions.

## Scope boundary: 15 agent definitions, not 17

`file_scope` named 15 implementation agent definitions.
`agent-system/extensions/lean/agents/lean-implementation-agent.md` and
`lean-implementation-hard-agent.md` were deliberately left untouched — declared territory of a
separate, not-started task building the lean tier-vocabulary-to-build-scope mapping. After this
task, those two Lean definitions are the only implementation agent definitions in the source
store without the pointer; closing that gap belongs to whichever task next holds that territory.

## Impacts

- Any implementation agent dispatched through one of the 15 in-scope definitions now has a
  direct, literal pointer in its own Critical Requirements to the read-only history-inspection
  techniques, at the exact point where a tree-wide git operation would otherwise be chosen.
- Future implementation agents generated from the agent template inherit the pointer by
  construction.
- `git-safety.md`, the document that already owns "git as the safety mechanism," now cross-
  references the new page for the narrower historical-inspection case it does not itself cover.

## Follow-ups

- Propagating the pointer to the two Lean implementation agent definitions is explicitly
  deferred to the lean tier-vocabulary-to-build-scope-mapping task's own territory, not this
  task's to close.
- Adding a `lint-agent-contracts.sh` check for the new bullet's presence/consistency across all
  15 (now 17, once Lean is covered) files was explicitly excluded from this task's scope as a
  deliberate non-goal; recorded in the plan as a candidate follow-up, not an oversight.

## References

- Plan: `specs/362_shared_worktree_history_read_discipline/plans/01_shared-worktree-discipline.md`
- Research: `specs/362_shared_worktree_history_read_discipline/reports/01_shared-worktree-history-read-discipline.md`
- New page: `agent-system/extensions/core/context/standards/shared-worktree-discipline.md`
- Dispatch file (Batch Gate Deferral directive): `specs/362_shared_worktree_history_read_discipline/.dispatch/24.md`
