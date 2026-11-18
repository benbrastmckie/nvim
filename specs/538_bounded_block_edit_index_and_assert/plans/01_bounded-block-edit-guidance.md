# Implementation Plan: Task #538

- **Task**: 538 - Bounded in-file block edits: index and assert, never string-splice
- **Status**: [IMPLEMENTING]
- **Effort**: 3.25 hours
- **Dependencies**: None (live `dependencies: []`; the predecessor jq-reserialization record has
  landed and its outcome is readable directly from `jq-escaping-workarounds.md`)
- **Research Inputs**: specs/538_bounded_block_edit_index_and_assert/reports/01_bounded-block-edit-guidance.md
- **Artifacts**: plans/01_bounded-block-edit-guidance.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

This task's entire deliverable is prose guidance in the `core` extension's source store plus the
wiring that makes it reachable: a new `context/patterns/bounded-block-edit.md` carrying the
assertion discipline this record owns, an `index-entries.json` entry, and two referrers (the
implementer-audience bullet in `agents/general-implementation-agent.md` and a short
plan-author/broad-audience pointer section in `merge-sources/claudemd.md`). Because the sibling
anchor record is now completed with its guidance sited only inside the lean implementation flow,
this new file is also the shared core home that record invited: the anchor rule's landed paragraph
moves here verbatim and the lean copy is reduced to a pointer. Definition of done: all eight
acceptance criteria in the task description are met and
`bash .claude/scripts/deploy-headless.sh` reports `RESULT=landed_verify_clean`.

### Research Integration

The research report resolved both siting branches against the live repository, and this planning
dispatch independently re-confirmed every load-bearing fact:

- **Branch (i) — create the new file.** The predecessor jq record extended
  `agent-system/extensions/core/context/patterns/jq-escaping-workarounds.md` in place (its
  `## jq Rewrites Reflow Unrelated JSON Formatting` section begins at line 282 of a 351-line file)
  rather than creating a sibling pattern file; `ls` of `context/patterns/` confirms no
  reserialization sibling and no `bounded-block-edit.md` exists. So this record creates the new
  file already named in its `file_scope`.
- **Branch (ii) — this file is the shared home.** The anchor rule exists only as the
  `**Section-anchoring rule for any multi-line plan-file edit**` paragraph at lines 120-128 of
  `agent-system/extensions/lean/context/project/lean4/agents/lean-implementation-flow.md`, with one
  cross-reference at line 177 (Stage 4D). The sibling record that landed it is archived/completed
  (`lean_phase_commit_full_build_and_plan_anchor`, present only in `specs/archive/state.json`), so
  no live record claims those files and no serializing dependency edge is available or needed.
  That file's own index entry declares `load_when.agents: ["lean-implementation-agent"]` and
  `load_when.task_types: ["lean4"]` — mechanical confirmation of the audience-reach defect: a plan
  dispatch never loads it.
- **Mechanical shapes to reuse, not invent.** The `## Context References` bullet list in
  `agents/general-implementation-agent.md` (lines 21-36) already points at six sibling core
  patterns in exactly the shape this change adds a seventh bullet in; `## jq Command Safety` in
  `merge-sources/claudemd.md` (lines 250-268) is the precedent for a short inline rule plus a
  `Full documentation:` pointer; the `patterns/jq-escaping-workarounds.md` and
  `patterns/checkpoint-before-overflow.md` entries in `index-entries.json` (175 entries today) are
  the schema templates for the new entry.
- **Measured suite coverage.** `suite_selection_select` was run over every path this plan declares,
  so every `Tier Justification` below names real selector output rather than a guess: both markdown
  deliverables return `__FULL_SWEEP__`; `core/index-entries.json` and `lean/index-entries.json`
  each return `test-context-reachability.sh test-deploy-orphans.sh test-index-entries-schema.sh
  test-install-uninstall-extension.sh test-manifest-scripts-sync.sh
  test-roadmap-command-registration.sh`; `agents/general-implementation-agent.md` returns
  `test-lint-agent-contracts-heartbeat.sh test-lint-agent-contracts.sh
  test-orchestrate-build-dispatch.sh test-orchestrate-cycle-postflight.sh`; and
  `merge-sources/claudemd.md` returns `test-plan-file-scope-harvest.sh
  test-roadmap-command-registration.sh`.
- **Line-count baseline.** `generate-context-line-counts.sh --check` passes clean across all 602
  entries in all extensions right now, so the only `line_count` drift this change can introduce is
  the new core entry and the shrunk lean file — both inside this task's own declared scope. The
  same script is run automatically by `deploy-headless.sh` before every deploy.

### Premise Re-Validation (Carried-Figure Discipline)

Every extracted trigger-class line in the dispatch's `## Premise Re-Validation` block was checked
against live state. Result: **the description is unchanged and still accurate where it is
checkable**; nothing in it had to be corrected, and no plan content rests on an unverified figure.

| Carried claim | Check run | Result |
|---------------|-----------|--------|
| `git show HEAD:<path>` recovery is unguarded | Read `.claude/rules/git-workflow.md`'s forbidden-on-dirty-tree list | Confirmed: the list names `reset --hard`, `checkout -- <path>`, `restore <path>`, `clean -fd`, `stash drop/clear`, bare `stash`, forced `checkout`/`switch` — no read-only plumbing command, so `git show` has no guard interaction |
| A sibling record already covers the anchor half | `grep` of `specs/state.json` and `specs/archive/state.json`; read of lines 100-180 of the lean flow file | Confirmed: record is archived/completed; the paragraph is live at lines 120-128, cross-referenced at line 177 |
| Both records touch `index-entries.json` and `claudemd.md`; the predecessor has landed | `wc -l` and `grep -n '^## '` of `jq-escaping-workarounds.md`; live `dependencies` read | Confirmed: 351 lines with the reflow section at 282; live `dependencies: []`, so no edge to honour |
| "No helper script" scope decision | `ls` of `context/patterns/` and the core `scripts/` tree | Confirmed: no safe-block-editor helper exists, nothing to retire |
| Deliverable-hygiene rules apply | Both rule files read | Confirmed present and in force for every path this plan edits |
| Anchor rule must resolve to line indices, forward-searched | Read of the landed paragraph | Confirmed verbatim; it is correct as it stands and is to be moved, not reworded |
| The 773-line / 752-line duplications and commits `83085ed7e` / `f0ef67f81` | Not re-measured | These are historical figures from a different repository's history; they are **not load-bearing for any step of this plan** and, per deliverable hygiene, must not appear in the guidance prose at all. Carried forward as motivation only |

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No `roadmap_path` was provided in this dispatch's delegation context and no roadmap phases are
included.

## Goals & Non-Goals

**Goals**:
- Create `agent-system/extensions/core/context/patterns/bounded-block-edit.md` stating the
  conjunctive trigger condition, the `Edit`-first mechanism choice, the three-part
  index-and-assert recipe, the transplanted anchoring rule, the `git show HEAD:<path>` recovery
  nuance, an explicit scope boundary, and a reopen condition.
- Make the guidance reachable by both audiences: the implementer via a `## Context References`
  bullet in `agents/general-implementation-agent.md`, and the plan-author/broad audience via a
  short pointer section in `merge-sources/claudemd.md`.
- Register the file in `agent-system/extensions/core/index-entries.json` with a `line_count` and
  `keywords` that agree with the file as landed.
- Consolidate the anchor half: move the landed lean paragraph into the new shared home verbatim and
  reduce the lean copy to a pointer, so one place serves both audiences.
- Land it all: `bash .claude/scripts/deploy-headless.sh` reporting `RESULT=landed_verify_clean`.

**Non-Goals**:
- No helper script, wrapper, or "safe block editor" tool. The reopen condition names the signal
  that would revisit this.
- No edit to `agents/planner-agent.md`. That path is claimed by the plan-format
  blocked-decision-gate record; the plan-author audience is reached through `claudemd.md` instead.
  Any future need for a `planner-agent.md` line requires a new serializing dependency edge, not an
  edit here.
- No rewording, re-derivation, or "improvement" of the anchor rule's sentences. It moves verbatim.
- No re-edit of the plan file whose duplication motivated this record; nothing in the repository is
  broken and this is not a data-repair task.
- No hand edit anywhere under `.claude/**`. Every edit targets the source store; the deployed tree
  is regenerated by the deploy in the final phase.
- No restatement of the destructive-git rules beyond the one recovery nuance.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| The anchor rule gets reworded instead of moved, producing two subtly different rules | H | M | Phase 3 transplants lines 120-128 of the lean file as an exact block copy and verifies with a `diff` of the two extracted blocks before the lean copy is reduced; any generalization is added as surrounding framing, never by editing the paragraph's own sentences |
| The lean paths are edited while still outside the task's declared `file_scope` | M | M | Phase 3's first task is a `jq` read of the live `file_scope`; the paths are declared in this plan's `Files to modify` so plan-postflight harvest widens `file_scope` automatically, and the phase aborts to `proposed_file_scope` rather than editing silently if the widening is absent |
| A live orphan/reachability check flags the new file during the window between its creation and its index entry | L | M | The window is deliberate and bounded to Phases 1-3; no phase in that window runs the live `context-reachability.sh --check`, and the authoritative reachability verdict is the final phase's deploy result |
| `generate-context-line-counts.sh --write` reflows or touches index files outside this task's scope | M | L | A baseline `--check` run passes clean across all 602 entries today, so Phase 4 uses `--check` to learn the correct numbers and applies them as targeted single-value edits to the two declared files; `--write` is a fallback only, and `git status --short` is read before staging either way |
| A concurrent sibling dispatch (503, 526, 558) has already modified a shared file | M | M | None of the three siblings' declared scopes intersect this task's, but every file is re-read immediately before it is edited, staging is explicit-file-list only, and a foreign commit or modification is reported rather than absorbed |
| Guidance prose leaks a task number, an issue entry id, or draft-history framing | M | M | Phase 5's gate run includes the task-reference lint; Phase 1 and Phase 3 each end with a read-through against both deliverable-hygiene rules before the phase closes |
| An edit to `claudemd.md` or `general-implementation-agent.md` is itself a bounded block edit that could splice wrongly | M | L | Each is done with the `Edit` tool on a unique `old_string` — the first-choice mechanism the new guidance names — and each phase asserts a post-write structural count (`grep -c '^## '` / `grep -c '^- `@'`) |

## Decisions

- **The new file carries both halves.** Branch (ii) of the task description's resolution order is
  confirmed resolved: no core-extension home exists for the anchor rule, so this file becomes the
  shared home the sibling record invited. The anchor half moves in verbatim and the lean file keeps
  a pointer. This is what makes the third incident's audience-reach defect actually fixable: the
  rule stops being reachable only from a file that plan dispatches never load.
- **Two referrers, two audiences, named explicitly.** The implementer path is
  `agents/general-implementation-agent.md`'s `## Context References` bullet; the plan-author and
  general path is `merge-sources/claudemd.md`'s pointer section, which reaches every session
  through the generated root `CLAUDE.md`. The lean implementation agent keeps its reach through the
  pointer left in the lean flow file, plus `lean-implementation-agent` added to the new core
  entry's `load_when.agents`.
- **`agents/planner-agent.md` stays excluded**, on the same ground the predecessor record excluded
  it: the path is claimed elsewhere, and `claudemd.md` already reaches that audience.
- **Guidance only, no helper script**, per the task description's filing-time decision; the file
  itself states the reopen condition (the recipe being retyped across many tasks).
- **Index `line_count` and `keywords` are computed from the file as landed**, in a later phase than
  the one that writes the file, so they cannot be estimated ahead of the content.

## Implementation Phases

**Dependency Analysis**:

| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2, 3 | 1 |
| 3 | 4 | 1, 3 |
| 4 | 5 | 2, 4 |

Phases within the same wave can execute in parallel.

### Phase 1: Author the Shared Core Pattern File [COMPLETED]

**Goal**: Create `agent-system/extensions/core/context/patterns/bounded-block-edit.md` carrying
every content obligation in the task description's acceptance list, structured like
`jq-escaping-workarounds.md`'s reflow section (checkable trigger -> copyable recipe -> scope
boundary -> reopen condition -> references).

**Tasks**:
- [x] Read `agent-system/extensions/core/context/patterns/jq-escaping-workarounds.md` lines
      282-351 for the section shape to mirror (conjunctive trigger, numbered recipe, reopen
      condition, "not a general indictment" boundary paragraph). *(completed)*
- [x] Write the new file with these sections, in this order: *(completed)*
      - **Trigger condition**, stated conjunctively and checkable before acting: the target is a
        bounded block inside a larger line-structured text file (name at least one concrete shape:
        a phase inside a plan file; a section inside a document; a record inside a log), AND the
        mechanism under consideration reconstructs the file from string slices of its own content
        rather than replacing identified lines in place. State that both halves must hold, and that
        rewriting a whole file from computed content and a line-indexed in-place replacement are
        each outside the class.
      - **First choice: the `Edit` tool with a unique `old_string`**, stated before any scripted
        path, on the ground that it is itself a bounded, assert-on-match edit: it fails loudly when
        the match is absent or ambiguous, which is the pre-state assertion obtained for free.
      - **When the scripted path earns its place**: the edit is repetitive across many sites in one
        file, or mechanical enough that enumerating `Edit` calls is impractical (one heading marker
        plus a run of checklist items is the worked example).
      - **The three-part recipe**, copyable, with a short worked snippet: (1) index, do not splice
        — read the file into a list of lines, locate the block's start and end by matching the lines
        that delimit it, rewrite only that range, never concatenate character-offset slices;
        (2) bound the range by an explicit terminator and assert the pre-state before writing — the
        marker to be changed is present, the items match, the range terminated at a found
        terminator rather than at end of file — and abort without writing when an assertion fails;
        (3) assert a post-state invariant immediately after the write, in the same breath, naming a
        structural count (`grep -c '^### Phase'` for a sectioned document) as the cheapest and most
        sensitive invariant and a total line count as the weaker fallback that still catches gross
        duplication.
      - **Anchoring the range**: a placeholder subsection with a one-line forward reference, filled
        in by Phase 3's transplant. Phase 1 leaves a single clearly marked line here so Phase 3
        has a unique `old_string` to replace.
      - **Recovery when an edit goes wrong**: restoring one clobbered file is
        `git show HEAD:<path>` piped to a write — a blob read to stdout plus an ordinary file write,
        so no destructive-git guard is involved, no snapshot is required, and it works on a dirty
        tree. State that `git checkout --`, `git restore`, and `git reset --hard` are neither needed
        nor appropriate for this case, and cite `.claude/rules/git-workflow.md` for those rules
        rather than restating them.
      - **What this guidance does not say**: not a prohibition on scripted editing, not "always use
        the `Edit` tool", and the post-state assertion is not optional verification a careful editor
        may skip.
      - **Reopen condition**: if this assertion recipe is being retyped across many tasks, revisit
        the question of a helper wrapper then.
      - **References**: `.claude/rules/git-workflow.md`,
        `context/patterns/jq-escaping-workarounds.md`, `context/contracts/pre-edit-gate.md`.
- [x] Read the file back and confirm a reader can reach every acceptance obligation without
      knowing the term "slice-and-splice" in advance (the trigger condition is stated in
      mechanism terms, not jargon). *(completed)*
- [x] Check the prose against `.claude/rules/no-task-references-in-deliverables.md` and
      `.claude/rules/no-record-versioning-in-deliverables.md`: no task number, no issue entry id,
      no narration of a past incident's draft history, no "previously/no longer/formerly" framing.
      `grep -nE 'task [0-9]|iss_[0-9]|previously|no longer|formerly|supersedes'` over the new file
      must return nothing. *(completed: grep returned no matches)*
- [x] Commit this phase's single file with an explicit-file-list `git add`. *(completed)*

**Timing**: 1 hour

**Depends on**: none

**Verification Tier**: prose

**Commit Mode**: per-substep

**Tier Justification**: `suite_selection_select` returns `__FULL_SWEEP__` for the only path this
phase writes bytes to, so no suite covers it and none is claimed; the covering check is
`bash /home/benjamin/.config/nvim/.claude/scripts/verify-deploy.sh --skip-slow --only-gate 3,4 /home/benjamin/.config/nvim`
(sub-case (b): a source-store markdown edit, `TARGET` the repository root that holds both a
deployed `.claude/` tree and the source store) run together with the `prose` row's diff
read-through.

**Files to modify**:
- `agent-system/extensions/core/context/patterns/bounded-block-edit.md` - new file; the shared core
  home for the bounded-block-edit discipline
- `agent-system/extensions/core/index-entries.json` - declared only, not written in this phase:
  creating an unindexed `context/**` file moves the quantity this file derives
  (`line_count`/reachability). The check that detects the drift (`check-extension-docs.sh` Rule R)
  is advisory in this repository rather than commit-blocking and `deploy-headless.sh` auto-repairs
  it, so reconciliation is scheduled in Phase 4; this entry discharges the declaration obligation
  in the phase that moved the quantity. The file exists with 175 entries today; if it is absent or
  restructured when the phase runs, stop and record an issue rather than inventing a target

**Verification**:
- `test -s agent-system/extensions/core/context/patterns/bounded-block-edit.md` and
  `grep -c '^## ' agent-system/extensions/core/context/patterns/bounded-block-edit.md` returns the
  expected section count for the structure above.
- Every acceptance obligation is present: `grep -n` finds the trigger condition's conjunction, an
  `old_string` mention, a `git show HEAD:` occurrence, a `grep -c` style post-write assertion, the
  "does not say" boundary, and the reopen condition.
- The hygiene `grep -nE` above returns no matches.
- `bash /home/benjamin/.config/nvim/.claude/scripts/verify-deploy.sh --skip-slow --only-gate 3,4 /home/benjamin/.config/nvim`
  reports no new findings against this file.

---

### Phase 2: Wire Both Audiences' Referrers [COMPLETED]

**Goal**: Make the new guidance reachable from the implementer path
(`agents/general-implementation-agent.md`) and from the plan-author/broad path
(`merge-sources/claudemd.md`), each using the mechanism already established in that file.

**Tasks**:
- [x] Re-read `agent-system/extensions/core/agents/general-implementation-agent.md`'s
      `## Context References` section immediately before editing (a sibling dispatch may have
      touched the file). *(completed)*
- [x] Add exactly one bullet to that list, same shape as its existing sibling-pattern bullets
      (`` - `@.claude/context/patterns/bounded-block-edit.md` - `` plus a short when-to-load
      clause). The clause must name the situation in mechanism terms a reader recognizes without
      prior jargon: an in-file edit to a bounded block of a line-structured file, especially one
      done by reconstructing the file from string slices. Apply it with the `Edit` tool on a unique
      `old_string` (the adjacent `plan-revision-notification.md` bullet line). *(completed)*
- [x] Re-read `agent-system/extensions/core/merge-sources/claudemd.md` around its
      `## jq Command Safety` section (lines 250-268 as of authoring) for the pointer-section
      precedent. *(completed)*
- [x] Add one short `##` section to `claudemd.md`, mirroring that precedent's shape: two or three
      sentences stating the trigger and the first-choice mechanism inline, then a
      `Full documentation:` line pointing at
      `.claude/context/patterns/bounded-block-edit.md`. Do not duplicate the recipe there. Place it
      adjacent to `## jq Command Safety` so the two editing-hazard pointers sit together. *(completed)*
- [x] Assert the post-state of each edit in the same breath as the write: the `##` section count of
      `claudemd.md` increased by exactly one and its total line count increased by only the lines
      added; the `- `@`` bullet count in the agent file's `## Context References` increased by
      exactly one. *(completed: 18->19 sections, 282->292 lines, 12->13 bullets)*
- [x] Commit with an explicit two-file `git add`, after reading `git status --short` and
      `git diff --staged`. *(completed)*

**Timing**: 0.75 hours

**Depends on**: 1

**Verification Tier**: local

**Commit Mode**: per-substep

**Scope Hypothesis**: exactly two files change in this phase and each changes by a single added
block — one bullet line and one short `##` section. Confirm at implementation time with
`git diff --stat` showing two files and no deletions; a larger diff means an edit went off target
and must be reverted from `git show HEAD:<path>` before proceeding.

**Tier Justification**: `suite_selection_select` maps these two paths to exactly
`test-lint-agent-contracts-heartbeat.sh`, `test-lint-agent-contracts.sh`,
`test-orchestrate-build-dispatch.sh`, `test-orchestrate-cycle-postflight.sh`,
`test-plan-file-scope-harvest.sh`, and `test-roadmap-command-registration.sh`, which is covered by
`bash .claude/scripts/tests/run-all.sh --only test-lint-agent-contracts-heartbeat.sh,test-lint-agent-contracts.sh,test-orchestrate-build-dispatch.sh,test-orchestrate-cycle-postflight.sh,test-plan-file-scope-harvest.sh,test-roadmap-command-registration.sh`
(source-store form `bash agent-system/extensions/core/scripts/tests/run-all.sh --only ...` if the
deployed path does not resolve).

**Files to modify**:
- `agent-system/extensions/core/agents/general-implementation-agent.md` - add one bullet to the
  Context References section for the new pattern. That section exists at lines 21-36 with six
  sibling-pattern bullets today; if its shape has changed when the phase runs, locate it by
  running the heading grep named in this phase's tasks and match the then-current bullet shape
  rather than forcing the one described here
- `agent-system/extensions/core/merge-sources/claudemd.md` - add one short pointer section next to
  the jq Command Safety section. That section exists at lines 250-268 today; if it has moved,
  locate it by the heading grep named in this phase's tasks and place the new section adjacent to
  wherever it then sits

**Verification**:
- `grep -n 'bounded-block-edit.md' agent-system/extensions/core/agents/general-implementation-agent.md`
  returns exactly one line, inside `## Context References`.
- `grep -n 'bounded-block-edit.md' agent-system/extensions/core/merge-sources/claudemd.md` returns
  exactly one line, on a `Full documentation:` pointer.
- The two post-write count assertions above both hold.
- The `run-all.sh --only` command named in the Tier Justification passes.

---

### Phase 3: Consolidate the Anchor Half into the Shared Home [NOT STARTED]

**Goal**: Move the landed section-anchoring paragraph from the lean implementation flow into the
new core file verbatim, and reduce the lean copy to a pointer, so one place serves both the
implementer and the plan author.

**Tasks**:
- [ ] Confirm the task's live `file_scope` already contains both lean paths:
      `jq -r '.active_projects[] | select(.project_number==538) | .file_scope[]' specs/state.json`.
      They are declared in this plan, so plan-postflight harvest adds them. If they are absent,
      do NOT edit the lean files: record the paths in `proposed_file_scope` in
      `.return-meta.json` and stop this phase there, per the task description's widen-first
      instruction.
- [ ] Extract lines 120-128 of
      `agent-system/extensions/lean/context/project/lean4/agents/lean-implementation-flow.md`
      (the `**Section-anchoring rule for any multi-line plan-file edit**` paragraph) to a scratch
      file with `sed -n '120,128p'`, after confirming by `grep -n 'Section-anchoring rule'` that
      the paragraph still starts where expected.
- [ ] Replace the placeholder line Phase 1 left in the new core file's anchoring subsection with
      that extracted block, unchanged. Any generalization beyond markdown plan files is added as a
      sentence of framing around the block, never by editing the block's own sentences.
- [ ] Assert the transplant was faithful: `diff` the scratch extract against the corresponding
      lines of the new core file and confirm it is empty.
- [ ] Reduce the lean paragraph to a pointer: replace the same nine lines with two or three lines
      giving the rule's one-line gist (anchor both ends on heading LINES, search the end anchor
      forward from the section's own start) plus a pointer to
      `.claude/context/patterns/bounded-block-edit.md` for the full rule and the assertion
      discipline. Do this with the `Edit` tool on the paragraph's unique opening sentence as
      `old_string`, not a scripted splice.
- [ ] Leave line 177's Stage 4D cross-reference working: re-read it and adjust its wording only if
      it no longer resolves to a rule that is still stated there (the pointer keeps the gist, so it
      should still read correctly).
- [ ] Assert the post-state of the lean edit immediately: the file's `^### ` and `^## ` heading
      counts are unchanged, and `wc -l` has decreased by roughly six to seven lines and by nothing
      like a whole section.
- [ ] Check both edited files against the two deliverable-hygiene rules as in Phase 1.
- [ ] Commit with an explicit two-file `git add`.

**Timing**: 0.75 hours

**Depends on**: 1

**Verification Tier**: prose

**Commit Mode**: per-substep

**Scope Hypothesis**: the anchor rule's only live copy is the nine-line paragraph at lines 120-128
of the lean flow file, with one cross-reference at line 177 — confirmed at authoring time by a
repository-wide `grep` for `Section-anchoring rule`, which matched that one file only. Re-run that
same `grep -rn 'Section-anchoring rule'` at implementation time; if it now matches more than one
file, stop and report rather than transplanting a rule with a second live copy.

**Tier Justification**: `suite_selection_select` returns `__FULL_SWEEP__` for the lean flow file —
no suite covers it and none is claimed — so the covering check is
`bash /home/benjamin/.config/nvim/.claude/scripts/verify-deploy.sh --skip-slow --only-gate 3,4 /home/benjamin/.config/nvim`
plus the `prose` row's diff read-through and the `diff`-empty transplant assertion above.

**Files to modify**:
- `agent-system/extensions/lean/context/project/lean4/agents/lean-implementation-flow.md` - replace
  the nine-line anchoring paragraph with a pointer. Confirmed present at lines 120-128 with a
  cross-reference at line 177; if `grep -n 'Section-anchoring rule'` finds nothing when the phase
  runs, the relocation has already happened — record that and skip the edit rather than
  reconstructing the paragraph
- `agent-system/extensions/core/context/patterns/bounded-block-edit.md` - fill the anchoring
  subsection placeholder with the transplanted block plus framing
- `agent-system/extensions/lean/index-entries.json` - declared only, not written in this phase:
  shrinking the lean flow file moves the `line_count` this file derives for
  `project/lean4/agents/lean-implementation-flow.md` (261 today, matching the live file). The
  detecting check is advisory rather than commit-blocking here, so reconciliation is scheduled in
  Phase 4; the declaration is owed in this phase because this is where the quantity moves

**Verification**:
- The transplant `diff` is empty (the core file's anchoring block is byte-identical to the
  extracted original).
- `grep -n 'bounded-block-edit.md' agent-system/extensions/lean/context/project/lean4/agents/lean-implementation-flow.md`
  returns exactly one pointer line.
- The lean file's `^## ` and `^### ` heading counts are unchanged from before the edit; `wc -l` is
  lower by single digits.
- `bash /home/benjamin/.config/nvim/.claude/scripts/verify-deploy.sh --skip-slow --only-gate 3,4 /home/benjamin/.config/nvim`
  reports no new findings.

---

### Phase 4: Register and Reconcile the Index Entries [NOT STARTED]

**Goal**: Add the `index-entries.json` entry for the new pattern file with a `line_count` and
`keywords` that agree with the file as landed, and reconcile the lean entry's `line_count` for the
file Phase 3 shrank.

**Tasks**:
- [ ] Re-read `agent-system/extensions/core/index-entries.json` and extract the
      `patterns/jq-escaping-workarounds.md` and `patterns/checkpoint-before-overflow.md` entries as
      the schema templates (`path`, `domain`, `subdomain`, `summary`, `line_count`, `keywords`,
      `topics`, `load_when`).
- [ ] Compute `line_count` with `wc -l` on the finished
      `context/patterns/bounded-block-edit.md`, after Phases 1 and 3 are both closed.
- [ ] Add one entry: `path: "patterns/bounded-block-edit.md"`, `domain: "core"`,
      `subdomain: "patterns"`, a one-line `summary` naming both halves (bounded in-file block edits:
      line indexing, pre- and post-state assertions, and section anchoring), the measured
      `line_count`, `keywords` drawn from the file's own vocabulary (for example `patterns`,
      `file-editing`, `assertions`, `line-indexing`, `anchoring`, `plan-file-edit`),
      `topics: ["troubleshooting"]`, and
      `load_when: {"agents": ["general-implementation-agent", "lean-implementation-agent"],
      "task_types": [], "commands": ["/meta"]}` — the lean agent is included so the relocation does
      not cost it the reach the lean-sited paragraph used to give it.
- [ ] Apply the edit as an `Edit`-tool insertion on a unique neighbouring entry's text, not a
      whole-file `jq` rewrite: piping the file through `jq` reflows every unrelated record (see
      `context/patterns/jq-escaping-workarounds.md`'s reflow section).
- [ ] Run `bash .claude/scripts/generate-context-line-counts.sh --check` to learn the exact
      expected numbers and confirm the only reported mismatches are the two files this task
      touched.
- [ ] Apply the lean entry's corrected `line_count` as a single-value targeted `Edit` on
      `agent-system/extensions/lean/index-entries.json`. Use
      `generate-context-line-counts.sh --write` only if `--check` reports drift the targeted edit
      cannot express, and in that case read `git status --short` afterwards and stage only the two
      declared files.
- [ ] Re-run `--check` and confirm it passes clean for all entries.
- [ ] Validate JSON well-formedness of both files (`python3 -m json.tool` or equivalent) before
      committing, and commit with an explicit two-file `git add`.

**Timing**: 0.5 hours

**Depends on**: 1, 3

**Verification Tier**: local

**Commit Mode**: per-substep

**Scope Hypothesis**: exactly two index files change, by one added entry and one changed number
respectively; the baseline `--check` run at planning time passed clean across all 602 entries in
every extension, so no third extension should appear in the post-edit `--check` output. Confirm
with `git diff --stat` showing two files; any other extension's `index-entries.json` appearing in
the diff means `--write` reflowed more than intended and must be reverted from
`git show HEAD:<path>`.

**Tier Justification**: `suite_selection_select` maps both index files to exactly
`test-context-reachability.sh`, `test-deploy-orphans.sh`, `test-index-entries-schema.sh`,
`test-install-uninstall-extension.sh`, `test-manifest-scripts-sync.sh`, and
`test-roadmap-command-registration.sh`, covered by
`bash .claude/scripts/tests/run-all.sh --only test-context-reachability.sh,test-deploy-orphans.sh,test-index-entries-schema.sh,test-install-uninstall-extension.sh,test-manifest-scripts-sync.sh,test-roadmap-command-registration.sh`,
alongside `bash .claude/scripts/generate-context-line-counts.sh --check` as the direct check on the
derived quantity this phase reconciles.

**Files to modify**:
- `agent-system/extensions/core/index-entries.json` - add one entry for the new pattern file.
  Exists with 175 entries today; locate the insertion point by finding the neighbouring
  jq-escaping-workarounds entry
- `agent-system/extensions/lean/index-entries.json` - correct the `line_count` of the entry for
  the lean implementation-flow file (261 today). If Phase 3 skipped its lean
  edit, this entry needs no change and the task is recorded as a no-op rather than forced

**Verification**:
- `bash .claude/scripts/generate-context-line-counts.sh --check` exits 0 and reports all entries
  exact.
- Both JSON files parse.
- `jq -r '.entries[] | select(.path=="patterns/bounded-block-edit.md")'` on the core file returns a
  single entry whose `line_count` equals `wc -l` of the landed file and whose `keywords` are drawn
  from that file's own vocabulary.
- The `run-all.sh --only` command named in the Tier Justification passes.

---

### Phase 5: Deploy, Verify, and Close [NOT STARTED]

**Goal**: Regenerate the deployed tree from the source store and confirm the complete gate set is
green, discharging the task description's final acceptance criterion.

**Tasks**:
- [ ] Read `git status --short` and confirm the working tree carries only this task's own
      committed work plus whatever a concurrent sibling legitimately owns; report rather than
      absorb anything foreign.
- [ ] Run the deploy with the bounded-wait idiom the dispatch requires:
      `timeout 540 bash .claude/scripts/deploy-headless.sh`, with the Bash tool timeout raised to
      600000 ms (not the 120000 ms default), per
      `context/patterns/external-process-wait.md` Rule 1.
- [ ] Confirm the deploy reports `RESULT=landed_verify_clean`. On any other result, read the
      deploy's own findings, fix forward in the source store, and re-run — never hand-patch
      anything under `.claude/**`.
- [ ] Run the complete gate set: `bash .claude/scripts/verify-deploy.sh` (the full aggregator, not
      a `--only-gate` subset and not `--skip-slow`), and confirm it is green — including the
      doc-lint and task-reference gates that check the new guidance's prose.
- [ ] Confirm the new guidance is reachable in the deployed tree:
      `.claude/context/patterns/bounded-block-edit.md` exists, the deployed root `CLAUDE.md`
      carries the pointer section, and the deployed
      `.claude/agents/general-implementation-agent.md` carries the new bullet.
- [ ] Walk the task description's eight acceptance criteria one by one and record the evidence for
      each in the implementation summary.
- [ ] Commit any files the deploy itself rewrote in the source store (line counts), with an
      explicit file list.

**Timing**: 0.75 hours

**Depends on**: 2, 4

**Verification Tier**: full

**Commit Mode**: per-substep

**Files to modify**:
- `__WHOLE_TREE__` - this phase invokes whole-tree regeneration via the deploy script named in
  its tasks, which is an implicit scope claim over the entire deployed tree; declared with the
  reserved sentinel rather than by naming any deployed-tree path
- `agent-system/extensions/core/index-entries.json` - may be rewritten in place by the deploy's
  automatic `generate-context-line-counts.sh` pass
- `agent-system/extensions/lean/index-entries.json` - same; may be rewritten in place by the
  deploy's automatic line-count pass

**Verification**:
- `timeout 540 bash .claude/scripts/deploy-headless.sh` reports `RESULT=landed_verify_clean`.
- `bash .claude/scripts/verify-deploy.sh` — the complete gate set it aggregates, with no
  `--only-gate` filter and no `--skip-slow` — is green.
- All three deployed-tree reachability checks above hold.
- All eight acceptance criteria from the task description are satisfied with named evidence.

---

## Testing & Validation

- [ ] `agent-system/extensions/core/context/patterns/bounded-block-edit.md` exists and states the
      conjunctive trigger condition with at least one concrete qualifying file shape named
      (acceptance 1).
- [ ] It carries a copyable recipe covering all three parts — line indexing, the bounded range with
      its pre-state assertion, and the post-write invariant assertion — not merely a prohibition
      (acceptance 2).
- [ ] It names the `Edit`-tool-with-unique-`old_string` path as the first choice and says when the
      scripted path earns its place instead (acceptance 3).
- [ ] It states the `git show HEAD:<path>` recovery nuance, including that this is a plain write
      with no destructive-git-guard interaction, and does not restate the guard's own rules
      (acceptance 4).
- [ ] It does not generalize into a prohibition on scripted editing (acceptance 5).
- [ ] A reader arriving from `agents/general-implementation-agent.md` or from the root `CLAUDE.md`
      pointer reaches the guidance without knowing the term "slice-and-splice" in advance
      (acceptance 6).
- [ ] The `index-entries.json` entry's `line_count` and `keywords` agree with the file as landed,
      and at least one referrer exists (acceptance 7).
- [ ] `bash .claude/scripts/deploy-headless.sh` reports `RESULT=landed_verify_clean` (acceptance 8).
- [ ] `bash .claude/scripts/generate-context-line-counts.sh --check` passes clean.
- [ ] No edited file outside `specs/**` carries a task number, an issue entry id, or
      record-versioning language.

## Artifacts & Outputs

- `agent-system/extensions/core/context/patterns/bounded-block-edit.md` (new) — the shared core
  home for both halves of the bounded-block-edit discipline.
- `agent-system/extensions/core/index-entries.json` — one added entry.
- `agent-system/extensions/core/agents/general-implementation-agent.md` — one added
  `## Context References` bullet (implementer audience).
- `agent-system/extensions/core/merge-sources/claudemd.md` — one added short pointer section
  (plan-author and general audience).
- `agent-system/extensions/lean/context/project/lean4/agents/lean-implementation-flow.md` — the
  anchoring paragraph reduced to a pointer.
- `agent-system/extensions/lean/index-entries.json` — one reconciled `line_count`.
- `specs/538_bounded_block_edit_index_and_assert/summaries/01_bounded-block-edit-guidance-summary.md`
  — implementation summary recording the evidence for all eight acceptance criteria.

## Rollback/Contingency

Every phase is one or two files and commits independently, so the ordinary recovery for a botched
edit is the very mechanism this task documents: `git show HEAD:<path> > <path>` to restore one
clobbered file from the last commit, then redo the edit correctly. That is a blob read plus a plain
write, needs no snapshot, and works on a dirty tree — so a concurrent sibling's uncommitted work is
never at risk.

If the final deploy cannot be made to report `RESULT=landed_verify_clean`, do not hand-patch
`.claude/**`: fix forward in the source store and re-run. If the guidance content itself proves
unacceptable at the gate, the new pattern file and its index entry can be removed and the lean
paragraph restored from history with the same `git show` route, leaving the repository exactly as
it began — nothing in it is broken today, so reverting costs nothing.

Should a genuine whole-tree rollback ever be required (it should not be, for a guidance-only
change), use the snapshot-then-rollback recipe in `context/contracts/recovery.md`'s rollback rung,
including its out-of-scope override flag — never a bare precautionary `git-snapshot.sh` as a
start-of-phase checkpoint.
