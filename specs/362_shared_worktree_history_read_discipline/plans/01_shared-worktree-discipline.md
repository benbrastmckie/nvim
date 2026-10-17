# Implementation Plan: Task #362

- **Task**: 362 - Teach the non-destructive history-read techniques at the point of use, so an implementation agent inspecting past file state never reverts a shared working tree
- **Status**: [IMPLEMENTING]
- **Effort**: 3 hours
- **Dependencies**: 356 (bounded-wait propagation, confirmed complete), 359 (lint curated-array coverage, confirmed complete)
- **Research Inputs**: specs/362_shared_worktree_history_read_discipline/reports/01_shared-worktree-history-read-discipline.md
- **Artifacts**: plans/01_shared-worktree-discipline.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Author one short standards page, `context/standards/shared-worktree-discipline.md`, in the core
extension source store, naming the read-only history-inspection techniques and the three
forbidden tree-reverting git commands; then make it reachable by adding one short literal
MUST-NOT bullet citing it by path to each of the 15 implementation agent definitions named in
this task's `file_scope`, plus a forward-looking entry in the agent template so future generated
implementation agents inherit the pointer by construction. Register the new page in the core
extension's `index-entries.json` and add a one-line cross-reference from `git-safety.md` (the
document that owns "git as the safety mechanism"), so the owning document points at the new page
even though the content lives elsewhere. Redeploy and demonstrate the pointer chain with a
reproducible grep rather than asserting reachability.

### Research Integration

Findings carried directly into this plan:

- **Placement**: both candidate documents the dispatch asked to be surveyed were surveyed in full
  and rejected — `git-safety.md` (705 lines) is a before/during risky-operation
  safety-commit/rollback playbook with no natural home for point-of-use read-only guidance, and
  **no implementation agent definition references it at all** (`grep -rl "git-safety"
  agent-system/extensions/*/agents/*.md` is empty), so amending it would not by itself improve
  reachability; `git-workflow-narrative.md` (259 lines) already carries the full incident
  narrative but is self-described as a lazily-loaded *reactive elaboration* read only once an
  agent is already following the core rules — the opposite of findable at the moment a git
  command is chosen. An archived precedent task faced the identical placement question for
  closely analogous content and reached the same conclusion, producing
  `context/standards/post-incident-verification-checklist.md` (72 lines), whose structure and
  `## Placement` section are the template for the new page.
- **Reachability mechanism**: an `@`-style entry in an agent's own Context References list does
  not auto-resolve into a dispatched subagent's context, and full literal duplication of the
  whole page into 15 files would make "a section, not a framework" false in spirit. The
  right-sized mechanism is the shape already living in `general-implementation-agent.md` Critical
  Requirements MUST NOT item 10 (history rewrites under concurrent writers): a short literal
  bullet naming the forbidden commands and the read-only alternative, ending in a path citation.
- **Carried figures**: the two-agent bare-`git stash` count is re-confirmed with no divergence
  against `git-workflow-narrative.md`'s own incident section. The detached-worktree planner
  instance and the `git show <stash-ref>:path` self-recovery instance are **not re-derivable from
  this repository** — the originating batch ran in a separate consumer repository whose `specs/`
  artifacts are not on this filesystem. Disposition: treat both as illustrative, never cited as
  confirmed facts in the new page. The page's required content is prescriptive guidance and does
  not depend on them.
- **Registration surface correction**: the research recommended registering in
  `.claude/context/index.json`. That is the deployed, disposable copy. The actual edit target is
  `agent-system/extensions/core/index-entries.json`, from which the deployed index is generated;
  `check-extension-docs.sh` Rule S (deployed-index-orphan) is the check that makes registration
  mandatory, and Rules R/T govern the entry's `line_count` accuracy and schema.
- **No manifest edit needed**: `manifest.json`'s `provides.context` lists directories, and
  `standards` is already present, so Rule L (deployed context orphan) is satisfied without
  touching the manifest.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No `roadmap_path` was provided in this dispatch; no roadmap phases are added.

## Goals & Non-Goals

**Goals**:

- A short, single-topic standards page exists naming the read-only techniques
  (`git show HEAD:path`, `git show <ref>:path`, `git diff HEAD -- path`, scratchpad copy for a
  mutable experiment) and the three forbidden tree-reverting commands (`git stash` bare/whole-tree,
  `git checkout -- <path>`, `git restore <path>`).
- The page is reachable from the implementation agent definitions via a live, path-citing bullet
  in each file's existing Critical Requirements MUST NOT list, and that reachability is
  demonstrated with a reproducible grep.
- Future generated implementation agents inherit the pointer by construction via the agent
  template.
- The detached-worktree technique is mentioned only with an explicit READ-ONLY INSPECTION
  TECHNIQUE label and an explicit statement that it is not an isolation strategy.
- Net document count increase is exactly one, with the rejected placements recorded in the page
  itself.
- The change lands in the deployed tree and the full gate set is green.

**Non-Goals**:

- Proposing, revisiting, or deferring per-agent worktree isolation. The question is settled by
  `specs/decisions/worktree-isolation-removal-reaffirmation.md` and reaffirmed in the
  measured-co-scheduling-signal task's non-goals. Nothing in any deliverable may reopen it.
- Modifying `guard-destructive-git.sh` or `rules/git-workflow.md` — the stash-reclassification
  task's territory.
- Authoring a post-incident verification checklist — already a separate, completed task whose
  output (`context/standards/post-incident-verification-checklist.md`) this plan only cites.
- Editing wait-pattern documents or the no-op detection hook — the single-writer-discipline
  task's territory.
- Duplicating the bounded-wait contract text. This page covers tree-wide git operations only.
- Hand-editing any deployed `.claude/**` copy.
- **Adding a `lint-agent-contracts.sh` check for the new bullet.** The lint script is not in this
  task's `file_scope`, and a curated-array contract check is a framework, not a section. Recorded
  here as a deliberate exclusion and a candidate follow-up, not an oversight.
- **Covering the two Lean implementation agent definitions.** See the scope-boundary note below.

### Scope boundary: 15 agent definitions, not 17

`file_scope` names **15** implementation agent definitions (the research report says 14; the
divergence is recorded in this task's issue log). Seventeen implementation agent definitions
exist in the source store: `lean/agents/lean-implementation-agent.md` and
`lean/agents/lean-implementation-hard-agent.md` are deliberately absent from `file_scope` and are
the declared `file_scope` territory of the not-started lean tier-vocabulary-to-build-scope-mapping
task. This plan honors that exclusion rather than silently expanding scope. Consequence, stated
plainly: after this task, the two Lean implementation agent definitions are the only
implementation agent definitions without the pointer. The acceptance criterion ("reachable from
the implementation agent definitions via a live pointer, demonstrated") is still met for the 15
in-scope definitions and the template; closing the Lean gap belongs to whichever task next holds
that territory.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| A reader takes the detached-worktree mention as reopening worktree isolation | H | L | Explicit "READ-ONLY INSPECTION TECHNIQUE, never an isolation strategy" label inline, plus one sentence distinguishing it in both duration (seconds, within one dispatch) and effect (zero writes to the shared tree) from the settled architectural question |
| 16 near-identical edits drift in wording, so the bullet reads differently per agent | M | M | Phase 2 fixes the exact bullet text once and Phase 3 copies it verbatim; Phase 4 greps all 16 files for the cited path and for the three forbidden command names |
| New source context file deployed without an `index-entries.json` entry trips Rule S on the next redeploy | M | M | Registration happens in Phase 1, in the same phase as the file's creation, so no phase boundary leaves an unregistered file behind |
| `line_count` in the new index entry goes stale as the page is edited | L | M | `deploy-headless.sh` runs `generate-context-line-counts.sh --write` automatically before every deploy; Phase 4 additionally runs `--check` and reads its exit status |
| Content accidentally duplicates the bounded-wait contract or the no-op-spin task's wait guidance | M | L | The page is restricted to tree-wide git operations; Phase 1 verification greps the new page for `bounded`/`await`/`no-op` and confirms absence |
| A task-number reference leaks into a file under `agent-system/**` | M | L | Gate 4 (task-reference lint) is named in every phase's verification, and the bullet text in this plan contains no task numbers |

## Implementation Phases

**Dependency Analysis**:

| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2 | 1 |
| 3 | 3 | 2 |
| 4 | 4 | 3 |

Phases within the same wave can execute in parallel. This plan is a strict chain: Phase 2's
bullet cites a path that Phase 1 creates, Phase 3 copies the text Phase 2 fixes, and Phase 4
verifies all of it against the deployed tree.

---

### Phase 1: Author and register the shared-worktree discipline page [COMPLETED]

**Goal**: The new standards page exists in the source store, is registered so the next redeploy
does not orphan it, and the document that owns git safety points at it.

**Tasks**:

- [x] Create `agent-system/extensions/core/context/standards/shared-worktree-discipline.md`,
      modeled on `context/standards/post-incident-verification-checklist.md` in length and
      structure (that file is 72 lines; target well under 100). Required content, in this order:
  - A one-line why: parallel dispatches share one working tree by design, so a tree-wide or
    path-reverting git operation reverts work a sibling dispatch or the user has not committed
    yet, with no reliable per-session recovery.
  - **Read history**: `git show HEAD:path`, `git show <ref>:path`. **Read differences**:
    `git diff HEAD -- path`. Each as a copy-pasteable command, not a description of one.
  - **Mutable copy**: copy the extracted content to the session scratchpad directory (the path
    the environment block names) for any experiment needing a writable file; never materialize it
    back into the shared tree.
  - **Never, on a shared tree**: `git stash` (bare or whole-tree), `git checkout -- <path>`,
    `git restore <path>` — one clause each saying it reverts the tree out from under concurrent
    writers.
  - **Detached worktree**: for the narrower case of needing to *run* a command against historical
    state rather than read a file's text. Label it explicitly a READ-ONLY INSPECTION TECHNIQUE and
    state in the same breath that it is not an isolation strategy, distinguishing it in duration
    (seconds, inside one dispatch) and effect (zero writes to the shared tree) from the settled
    per-dispatch worktree isolation question — without restating, re-arguing, or deferring that
    question.
  - A `## Placement` section recording the rejected placements with the reasoning from Research
    Integration above, mirroring the precedent page's own `## Placement` section.
  - One closing pointer line to `context/standards/git-workflow-narrative.md`'s incident section
    for full mechanism detail.
- [x] Cite only the confirmed figure if any incident detail is referenced at all; do not cite the
      detached-worktree planner instance or the `git show <stash-ref>:path` self-recovery instance
      as facts (see Research Integration).
- [x] Add one `{path, domain, subdomain, summary, line_count, keywords, topics, load_when}` entry
      for `standards/shared-worktree-discipline.md` to
      `agent-system/extensions/core/index-entries.json`, matching the shape of the existing
      `standards/post-incident-verification-checklist.md` entry (`domain: "core"`,
      `subdomain: "standards"`, `topics: ["git-workflow"]`). **Decision on `load_when.agents`**:
      enumerate all 15 in-scope implementation agent names, not the single-agent form the
      precedent entry uses — this task's own scope is all 15, and a one-agent registration would
      reproduce, in the index, the same discoverability gap this task exists to close. Record that
      choice in the entry's `summary` or in the commit message.
- [x] Add one cross-reference line to `agent-system/extensions/core/context/standards/git-safety.md`
      (its `## References` list, or the end of its `## A Second Hazard Class` section), pointing at
      `context/standards/shared-worktree-discipline.md` for read-only history inspection on a
      shared tree. One line only — the dispatch's stated preference for amending this file is
      honored as a cross-reference, with the substantive content placed where it is findable.
- [ ] Commit the phase.

**Timing**: 0.8 hours

**Depends on**: none

**Verification Tier**: local

**Tier Justification**: `suite_selection_select` returns `__FULL_SWEEP__` for these paths (no
suite covers a pure-guidance markdown or index-entries edit), so the covering check is the gate
subset `bash agent-system/extensions/core/scripts/verify-deploy.sh --skip-slow --only-gate 3,4
/home/benjamin/.config/nvim` (gate 3 doc-lint, carrying Rules R/S/T on the new index entry; gate 4
task-reference lint), run with the diff read-through the `local` row prescribes.

**Scope Hypothesis**: the new page lands at or under 100 lines and no `manifest.json` edit is
needed because `provides.context` already lists the `standards` directory. Confirm at
implementation time with `wc -l` on the new file and by re-reading
`agent-system/extensions/core/manifest.json`'s `provides.context` array before concluding no
manifest change is required.

**Files to modify**:

- `agent-system/extensions/core/context/standards/shared-worktree-discipline.md` - new page (the
  only new file in this task)
- `agent-system/extensions/core/index-entries.json` - one added entry
- `agent-system/extensions/core/context/standards/git-safety.md` - one cross-reference line

**Verification**:

- `wc -l agent-system/extensions/core/context/standards/shared-worktree-discipline.md` reports a
  line count at or under 100.
- The page greps positive for `git show HEAD:`, `git diff HEAD --`, `git stash`,
  `git checkout --`, `git restore`, `READ-ONLY`, and `## Placement`.
- The page greps **negative** for `bounded`, `await`, and `no-op` (no overlap with the bounded-wait
  or no-op-spin territory), and contains no proposal, deferral, or re-argument of worktree
  isolation (read the detached-worktree paragraph aloud against the Non-Goals before closing).
- `python3 -c "import json; json.load(open('agent-system/extensions/core/index-entries.json'))"`
  parses, and the new entry is present with every Rule T required key.
- `bash agent-system/extensions/core/scripts/generate-context-line-counts.sh --check` exits 0 (or
  names only the new entry, which is then corrected with `--write`).
- `bash agent-system/extensions/core/scripts/verify-deploy.sh --skip-slow --only-gate 3,4
  /home/benjamin/.config/nvim` exits 0; read the exit status, not only the output text.

---

### Phase 2: Fix the canonical bullet text in the core agent and the agent template [COMPLETED]

**Goal**: The exact pointer bullet exists once, verbatim, in the canonical implementation agent
definition and in the template that generates future ones — establishing the text Phase 3 copies.

**Tasks**:

- [x] Append a new numbered item to
      `agent-system/extensions/core/agents/general-implementation-agent.md`'s Critical
      Requirements **MUST NOT** list (currently ends at item 15, so the new item is 16), modeled on
      that same list's item 10 in shape and length. Canonical text, to be used verbatim here and in
      Phase 3 (renumbered per file):

      ```
      16. Run a tree-wide or path-reverting git operation on this shared working tree to inspect
          or recover historical file state -- `git stash` (bare or whole-tree),
          `git checkout -- <path>`, or `git restore <path>`. Each reverts the tree out from under
          concurrent writers, which share this one working tree by design. Read history with
          `git show HEAD:path` or `git show <ref>:path`, read differences with
          `git diff HEAD -- path`, and copy to the session scratchpad when an experiment needs a
          mutable file -- see `context/standards/shared-worktree-discipline.md`.
      ```

- [x] Add one forward-looking bullet to
      `agent-system/extensions/core/context/templates/agent-template.md`'s
      `### Implementation Agent` variant list, as a sibling of the existing bounded-wait bullet
      there and mirroring its framing: carry the shared-worktree MUST NOT bullet from
      `context/standards/shared-worktree-discipline.md` in `## Critical Requirements`; state that
      this is forward-looking only (it covers a newly authored agent by construction) and is not a
      substitute for propagating the bullet into an already-existing agent definition.
- [ ] Commit the phase.

**Timing**: 0.5 hours

**Depends on**: 1

**Verification Tier**: local

**Scope Hypothesis**: `general-implementation-agent.md`'s Critical Requirements MUST NOT list
currently ends at item 15, making the new item 16. Confirm at implementation time by reading the
final numbered item under that file's `**MUST NOT**` heading rather than trusting the number here;
if the list has grown since this plan was written, use the actual next number.

**Tier Justification**: `suite_selection_select` returns `__FULL_SWEEP__` for agent-definition and
template markdown, so the covering check is the gate subset `bash
agent-system/extensions/core/scripts/verify-deploy.sh --skip-slow --only-gate 3,4,6
/home/benjamin/.config/nvim` — gate 6 being `lint-agent-contracts.sh`, the one check that reads
agent-definition contract structure.

**Files to modify**:

- `agent-system/extensions/core/agents/general-implementation-agent.md` - one MUST NOT item
  appended
- `agent-system/extensions/core/context/templates/agent-template.md` - one variant bullet added

**Verification**:

- `grep -n "shared-worktree-discipline" agent-system/extensions/core/agents/general-implementation-agent.md`
  returns a hit inside the Critical Requirements MUST NOT list (confirm by line number against
  the `## Critical Requirements` heading's line).
- The appended item's number is exactly one greater than the previous last item in that list, and
  the list has no duplicate or skipped numbers.
- `grep -n "shared-worktree-discipline" agent-system/extensions/core/context/templates/agent-template.md`
  returns a hit inside `### Implementation Agent`.
- `bash agent-system/extensions/core/scripts/verify-deploy.sh --skip-slow --only-gate 3,4,6
  /home/benjamin/.config/nvim` exits 0.

---

### Phase 3: Propagate the bullet to the 14 extension agent definitions [NOT STARTED]

**Goal**: Every in-scope implementation agent definition carries the same pointer bullet, so the
page is reachable from whichever implementation agent a dispatch happens to route to.

**Tasks**:

- [ ] Append the Phase 2 bullet text, verbatim apart from its leading number, to the Critical
      Requirements **MUST NOT** list of each of these 14 files. Each file's list already exists;
      the observed current last-item numbers are the starting hypothesis below, to be re-read per
      file rather than trusted:
  - `agent-system/extensions/books/agents/books-implementation-agent.md` (after 14)
  - `agent-system/extensions/books/agents/books-implementation-hard-agent.md` (after 16)
  - `agent-system/extensions/cslib/agents/cslib-implementation-agent.md` (after 24)
  - `agent-system/extensions/cslib/agents/cslib-implementation-hard-agent.md` (after 14)
  - `agent-system/extensions/cslib/agents/pr-review-implementation-agent.md` (after 12)
  - `agent-system/extensions/email/agents/email-implementation-agent.md` (after 8)
  - `agent-system/extensions/latex/agents/latex-implementation-agent.md` (after 9)
  - `agent-system/extensions/nix/agents/nix-implementation-agent.md` (after 15)
  - `agent-system/extensions/nvim/agents/neovim-implementation-agent.md` (after 13)
  - `agent-system/extensions/python/agents/python-implementation-agent.md` (after 9)
  - `agent-system/extensions/rust/agents/rust-implementation-agent.md` (after 9)
  - `agent-system/extensions/typst/agents/typst-implementation-agent.md` (after 11)
  - `agent-system/extensions/web/agents/web-implementation-agent.md` (after 16)
  - `agent-system/extensions/z3/agents/z3-implementation-agent.md` (after 9)
- [ ] Do **not** touch `agent-system/extensions/lean/agents/lean-implementation-agent.md` or
      `lean-implementation-hard-agent.md` — out of `file_scope` and another task's declared
      territory (see the scope-boundary note above).
- [ ] Commit the phase. A single commit for all 14 files is appropriate here: the edits are one
      propagation of one bullet, and a partially-propagated state is not independently meaningful.
      Declare it as the atomic batch it is rather than committing file by file.

**Timing**: 1 hour

**Depends on**: 2

**Verification Tier**: local

**Commit Mode**: atomic-batch

**Scope Hypothesis**: exactly 14 files, each with an existing `## Critical Requirements` section
containing a numbered `**MUST NOT**` list whose last item number is as listed above. Confirm per
file at implementation time by locating the `**MUST NOT**` heading and reading the final numbered
item before appending; a file whose structure differs from the hypothesis gets the bullet placed
in its nearest analogous section and that deviation recorded, not forced into a list that is not
there.

**Tier Justification**: `suite_selection_select` returns `__FULL_SWEEP__` for agent-definition
markdown, so the covering check is the gate subset `bash
agent-system/extensions/core/scripts/verify-deploy.sh --skip-slow --only-gate 3,4,6
/home/benjamin/.config/nvim`, gate 6 (`lint-agent-contracts.sh`) being the only check that reads
these files' contract structure.

**Files to modify**:

- The 14 extension implementation agent definitions enumerated above - one MUST NOT item appended
  to each

**Verification**:

- `grep -l "shared-worktree-discipline" agent-system/extensions/*/agents/*implementation*.md | wc -l`
  reports exactly 15 (the 14 from this phase plus the core agent from Phase 2).
- The two Lean definitions are **absent** from that grep's output — confirm explicitly, since
  their absence is a deliberate scope decision rather than an omission.
- Each edited file's MUST NOT list has consecutive numbering with no duplicate or skipped number.
- `bash agent-system/extensions/core/scripts/verify-deploy.sh --skip-slow --only-gate 3,4,6
  /home/benjamin/.config/nvim` exits 0.

---

### Phase 4: Redeploy, demonstrate reachability, close against the full gate set [NOT STARTED]

**Goal**: The change is live in the deployed tree, the pointer chain is demonstrated rather than
asserted, and the task closes against the complete gate set.

**Tasks**:

- [ ] Redeploy: `bash agent-system/extensions/core/scripts/deploy-headless.sh` (default
      non-destructive resync; it runs `generate-context-line-counts.sh --write` itself before
      deploying). `.claude/` is gitignored in this repository, so the redeploy produces no commit
      churn.
- [ ] Confirm freshness: `bash agent-system/extensions/core/scripts/check-deploy-freshness.sh`.
- [ ] Confirm the new page actually landed:
      `test -f .claude/context/standards/shared-worktree-discipline.md`, and
      `grep -c shared-worktree-discipline .claude/context/index.json` is at least 1 (Rule S's
      deployed-index-orphan condition satisfied from the generated index, not the source).
- [ ] **Demonstrate the pointer chain on the record** — this discharges the acceptance bullet that
      requires reachability to be demonstrated, not asserted. Record in the summary, with output:
      `grep -n "shared-worktree-discipline" .claude/agents/general-implementation-agent.md` (the
      deployed agent definition a dispatch actually reads) followed by
      `sed -n '/Read history with/,/shared-worktree-discipline/p' .claude/context/standards/shared-worktree-discipline.md`
      — a cited path from a deployed agent definition to the deployed section, reproducible by a
      reader.
- [ ] Run the complete gate set:
      `bash agent-system/extensions/core/scripts/verify-deploy.sh /home/benjamin/.config/nvim`
      (no `--skip-slow`, no `--only-gate`). Read the exit status directly. If a gate is red,
      determine from `git log` and `git status` whether it is pre-existing or this task's own, and
      report rather than assume. If this dispatch's own dispatch file carries a
      `## Batch Gate Deferral` directive, follow that directive instead of this bullet's unscoped
      form and say so explicitly in the summary — never silently narrow.
- [ ] Write the summary at
      `specs/362_shared_worktree_history_read_discipline/summaries/01_shared-worktree-discipline-summary.md`,
      recording: the placement decision and both rejections; the `load_when.agents` choice made in
      Phase 1 and why; the Lean scope boundary and its consequence; the carried-figure disposition
      (one confirmed, two unverifiable from this repository); and the reachability demonstration
      output verbatim.
- [ ] Commit the phase.

**Timing**: 0.7 hours

**Depends on**: 3

**Verification Tier**: full

**Files to modify**:

- `specs/362_shared_worktree_history_read_discipline/summaries/01_shared-worktree-discipline-summary.md` -
  new summary

**Verification**:

- `bash agent-system/extensions/core/scripts/deploy-headless.sh` succeeds and
  `check-deploy-freshness.sh` reports the deployed `core` tree current.
- `bash agent-system/extensions/core/scripts/verify-deploy.sh /home/benjamin/.config/nvim` — the
  complete gate set, all 23 gates, exit status read directly — exits 0.
- `bash agent-system/extensions/core/scripts/generate-context-line-counts.sh --check` exits 0.
- `bash .claude/scripts/check-task-references.sh` reports no new occurrence under
  `agent-system/**` (no task-number references in any deliverable outside `specs/**`).
- The reachability grep output is present in the summary, not merely described.

---

## Testing & Validation

- [ ] `agent-system/extensions/core/context/standards/shared-worktree-discipline.md` exists, is at
      or under 100 lines, and names all three forbidden commands and all three read-only
      techniques.
- [ ] The detached-worktree paragraph carries an explicit READ-ONLY INSPECTION TECHNIQUE label and
      an explicit "not an isolation strategy" statement, and proposes/defers nothing about
      worktree isolation.
- [ ] Exactly 15 implementation agent definitions plus `agent-template.md` cite the new page by
      path; the two Lean definitions deliberately do not.
- [ ] Net new document count is exactly one.
- [ ] `verify-deploy.sh` full run exits 0; `check-extension-docs.sh` Rules R, S, T and L are clean
      for the new entry.
- [ ] `check-task-references.sh` is clean for every file touched under `agent-system/**`.
- [ ] No file under `.claude/**` was hand-edited (every `.claude/**` change arrived via
      `deploy-headless.sh`).

## Artifacts & Outputs

- `agent-system/extensions/core/context/standards/shared-worktree-discipline.md` (new, the
  deliverable)
- `agent-system/extensions/core/index-entries.json` (one entry added)
- `agent-system/extensions/core/context/standards/git-safety.md` (one cross-reference line)
- `agent-system/extensions/core/agents/general-implementation-agent.md` and the 14 extension
  implementation agent definitions (one MUST NOT item each)
- `agent-system/extensions/core/context/templates/agent-template.md` (one variant bullet)
- `specs/362_shared_worktree_history_read_discipline/summaries/01_shared-worktree-discipline-summary.md`
- A regenerated `.claude/` deploy tree (gitignored, not committed)

## Rollback/Contingency

Every phase commits separately and every change is additive: one new file, one JSON entry, and
one appended list item per agent definition. Reverting is `git revert` of the phase commits in
reverse order followed by `bash agent-system/extensions/core/scripts/deploy-headless.sh` to bring
the deployed tree back in line — no destructive git operation on the working tree is needed, and
none may be used, since this repository's tree is shared with concurrent dispatches (the very
hazard this task documents).

If a gate in Phase 4 is red and traced to this task's own change, fix forward within the phase
rather than reverting: the failure modes available here are a malformed `index-entries.json`
entry (Rules R/T name the offending key, and `generate-context-line-counts.sh --write` fixes
`line_count`) or a misnumbered MUST NOT list (locate with the consecutive-numbering check in
Phase 3's verification). If work must stop mid-task, close the phase `[PARTIAL]` with the
remaining files enumerated; a partially-propagated bullet set is harmless — the page is already
reachable from whichever definitions were edited.
