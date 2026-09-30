# Implementation Plan: Task #278

- **Task**: 278 - Forbid Agent isolation forwarding in Move 2
- **Status**: [NOT STARTED]
- **Effort**: 1.5 hours
- **Dependencies**: None (no hard dependency edges declared; file_scope-driven serialization at
  admission handles coordination with the SKILL.md and orchestrate-cycle-plan.sh co-owners)
- **Research Inputs**: `specs/278_forbid_agent_isolation_forwarding_in_move_2/reports/01_forbid-isolation-forwarding.md`
- **Artifacts**: plans/01_forbid-isolation-forwarding.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md,
  source-store-deploy-boundary.md, no-task-references-in-deliverables.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Move 2 of `skill-orchestrate/SKILL.md` does not forbid forwarding a `dispatch[]` row's
`isolation`/`worktree_path` fields to the harness Agent tool's own `isolation` parameter, while
`orchestrate-cycle-plan.sh` emits both fields on every row. The collision is exact — `isolation`
is a real Agent-tool parameter and `"worktree"` is a valid value for it — so forwarding raises no
error, stacks a second harness checkout on the script-provisioned worktree, and leaves the
dispatched agent able to author and verify work but unable to commit it. This plan lands a
categorical point-of-use MUST NOT in Move 2, strengthens the emitting script's header from
descriptive wording into an explicit never-forward statement, and cross-links the existing design
record so rule and rationale surface each other. Definition of done: all three edits present in
the source store, each committed, with the full gate set green and no task-number reference
introduced outside `specs/**`.

### Research Integration

The research report confirmed every premise empirically and supplied two findings that shape the
plan. First, `grep -n isolation` over SKILL.md returns zero matches, so nothing is being replaced
— this is a pure insertion, and the file's established convention for a standalone contract line
is a `**MUST NOT**:` paragraph outside any code fence (two existing instances), not a bash comment
inside one. Second, the full enumeration of `dispatch[]` row fields (`task, phase, agent, model,
dispatch_file, force, focus, isolation, worktree_path`) shows only `agent` and `model` are ever
forwarded as Agent-tool arguments today, which makes the categorical phrasing requested by the
dispatch's "CONSIDER GENERALIZING" prompt free of cost. The report also established that
`batch-orchestration-guardrails.md`'s existing bullet argues a *different* rationale (`specs/`
staleness under whole-repo relocation), not the stacked-checkout hazard — so the optional third
edit is a genuine cross-link between complementary arguments, not a de-duplication, and is
retained as Phase 3 rather than dropped.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No `roadmap_path` provided for this dispatch; no ROADMAP.md consulted.

## Goals & Non-Goals

**Goals**:
- A categorical, self-justifying MUST NOT in Move 2 of
  `agent-system/extensions/core/skills/skill-orchestrate/SKILL.md`: no dispatch-row field is an
  Agent-tool argument unless Move 2 names it, with `isolation`/`worktree_path` as the named
  motivating example and the consequence stated in one clause.
- An explicit "never an Agent-tool argument" statement on the `isolation`/`worktree_path`
  documentation in `agent-system/extensions/core/scripts/orchestrate-cycle-plan.sh`'s output-schema
  header, replacing the too-weak "dispatch-site wiring" phrasing as the sole carrier.
- A two-way link between the new rule and the existing design record in
  `agent-system/extensions/core/context/patterns/batch-orchestration-guardrails.md`.

**Non-Goals**:
- No executable logic changes. `orchestrate-cycle-plan.sh`'s row-emission behavior, its
  `task_selected_for_worktree_isolation()` predicate, and both row builders are untouched; only
  the header comment changes.
- No new standalone context file. The research report's own recommendation is that point-of-use
  documentation in the two edited files suffices with only one confirmed collision; a
  `dispatch-row-vs-agent-tool-args.md` reference is explicitly deferred until a second collision
  appears.
- No test or script-test changes under `scripts/tests/`.
- No edit under `.claude/**`. That tree is a gitignored, disposable deploy artifact
  (confirmed: `git check-ignore` reports `/.claude/` from `.gitignore` line 6).
- No deploy-tree regeneration. Regeneration is manual-only and user-driven; the deploy tree will
  read stale for these three files until the user regenerates, which is expected and out of scope.
- No change to the `specs/`-staleness rationale already in `batch-orchestration-guardrails.md` —
  it remains valid and distinct, and is added to, never replaced.
- No work in the BimodalLogic repository. It is read-only evidence for the observed failure.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| A sibling task edits SKILL.md or orchestrate-cycle-plan.sh concurrently this same cycle (SKILL.md is co-owned by four other tasks; the script by four more) | M | M | Re-read the target file immediately before each edit per the Territory contract; stage only this task's own hunks with an explicit file list, never a directory or glob add; treat a foreign modification as a stop-and-report signal |
| The script's header block is relocated or rewritten by the co-owning decomposition task before this lands | M | L | Phase 2 locates the block by its content anchor (the `` `isolation` (`"none"` or `"worktree"` `` sentence), never by line number, and re-derives placement if the layout has changed |
| An edit crosses out of a shell comment region and breaks `orchestrate-cycle-plan.sh` syntax | H | L | Phase 2 runs `bash -n` on the file as its in-phase verification, and confirms the edited region is comment-only in the diff |
| The observed-evidence citation introduces a task-number reference into a deliverable outside `specs/**` | M | M | Phrase the evidence without any task or repository number ("20 of a dispatch's 21 phases"); Phase 4 runs `check-task-references.sh` as a gate |
| The categorical phrasing is read as banning any future use of a currently-unused row field | L | L | Phrase the rule with the "unless this section names it" escape hatch, so widening requires one visible edit to the same section rather than being forbidden outright |
| The new MUST NOT is placed inside the bash code fence and reads as another inert comment — the exact failure mode being fixed | M | L | Place it as prose outside the fence, matching the file's two existing `**MUST NOT**:` paragraphs |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2, 3 | 1 |
| 3 | 4 | 1, 2, 3 |

Phases within the same wave can execute in parallel.

### Phase 1: Add the categorical MUST NOT to Move 2 [NOT STARTED]

**Goal**: Move 2 carries an explicit, self-justifying prohibition on forwarding any un-named
dispatch-row field to the Agent tool, so a lead reconciling the abbreviated Agent-call comment
against a row carrying `isolation: "worktree"` reaches the right conclusion at the point of use.

**Tasks**:
- [ ] Re-read `skills/skill-orchestrate/SKILL.md` immediately before editing (Territory contract);
      confirm the `### Move 2: Dispatch` section and its two `while read` code fences are still
      shaped as the research report found them.
- [ ] Insert a new `**MUST NOT**:` paragraph inside the Move 2 section, as prose OUTSIDE any code
      fence — adjacent to the existing `**MUST NOT**:` paragraph about `aux_dispatch[]` rows,
      matching that paragraph's formatting convention exactly.
- [ ] Required content, all five elements present:
      (1) the categorical rule — no field of a `dispatch[]` or `aux_dispatch[]` row is an
      Agent-tool argument unless this section names it as one, which today means `agent`
      (-> `subagent_type`) and `model` only;
      (2) the note that the `Context: {...}` fields are prompt text, not tool arguments;
      (3) `isolation`/`worktree_path` named as the motivating example, stating that `isolation` is
      a real Agent-tool parameter whose enum includes `"worktree"`, so a forwarded row value is
      syntactically valid and raises no error;
      (4) the consequence in one clause — the row records a worktree `dispatch-worktree.sh`
      already provisioned; forwarding stacks a second harness checkout; the harness then refuses
      all cross-checkout git by design while still permitting file writes and build runs, so the
      agent authors and verifies its work green and then cannot commit it;
      (5) a forward pointer to `context/patterns/batch-orchestration-guardrails.md`'s
      "Deliberate Divergences" for the complementary rationale.
- [ ] Optionally cite the observed cost as a parenthetical, phrased with NO task number and NO
      repository name (e.g. "observed cost in one production run: 20 of a dispatch's 21 phases").
- [ ] Verify the new paragraph's wording does not depend on any surrounding line number.
- [ ] Commit this file's hunk alone with an explicit pathspec.

**Timing**: 25 minutes

**Depends on**: none

**Verification Tier**: prose

**Scope Hypothesis**: Exactly one file changes in this phase, by pure insertion of one prose
paragraph — no existing line is modified or deleted, because `grep -c -i isolation` over
`skills/skill-orchestrate/SKILL.md` currently returns `0`. Confirm at implementation time by
re-running that grep before the edit (expect `0`) and reading `git diff` afterwards (expect
additions only, zero deletions, and every added line outside a ``` fence).

**Files to modify**:
- `agent-system/extensions/core/skills/skill-orchestrate/SKILL.md` - insert one `**MUST NOT**:`
  prose paragraph in the `### Move 2: Dispatch` section

**Verification**:
- `grep -n -i "isolation" agent-system/extensions/core/skills/skill-orchestrate/SKILL.md` now
  returns matches, all within the Move 2 section.
- `git diff` shows additions only, and every added line sits outside a fenced code block (the
  research report's identified failure mode is placement inside the fence).
- All five required content elements are present in the added paragraph, checked by reading it.
- No task number or external repository name appears in the added text.

---

### Phase 2: State the never-forward rule in the emitting script's header [NOT STARTED]

**Goal**: The output-schema header that documents `isolation`/`worktree_path` says explicitly that
these fields record a posture already in effect and are never arguments to forward to the Agent
tool, rather than leaving "dispatch-site wiring" to carry that meaning implicitly.

**Tasks**:
- [ ] Re-read `scripts/orchestrate-cycle-plan.sh`'s header block immediately before editing
      (Territory contract — this file is co-owned by four other tasks, one of which decomposes it).
- [ ] Locate the `isolation`/`worktree_path` documentation by CONTENT anchor — the sentence
      beginning `` `isolation` (`"none"` or `"worktree"` `` — not by line number. If the file has
      been decomposed or the header relocated since this plan was written, re-derive where the
      note belongs in the new layout rather than assuming the original location.
- [ ] Extend that documentation with an explicit statement: both fields RECORD a posture already
      put into effect before the row was built (the worktree, if any, was provisioned earlier in
      this same function) and are consumed only by this pipeline's own downstream bookkeeping —
      never an argument passed to the Agent tool call.
- [ ] Add a forward pointer to the new Move 2 MUST NOT by section name (`skill-orchestrate/SKILL.md`'s
      Move 2), never by line number and never by task number.
- [ ] Keep every changed line inside the `#` comment region; change no executable line.
- [ ] Commit this file's hunk alone with an explicit pathspec.

**Timing**: 20 minutes

**Depends on**: 1

**Verification Tier**: local

**Scope Hypothesis**: The target is the `isolation`/`worktree_path` prose inside the single
output-schema comment block near the top of the file, and this phase changes comment lines only —
zero executable lines. Confirm at implementation time by locating the block via its content anchor
(not the line numbers recorded in the research report, which the co-owning decomposition task may
have invalidated) and by checking that every line in `git diff` on the `+`/`-` side begins with
`#`.

**Files to modify**:
- `agent-system/extensions/core/scripts/orchestrate-cycle-plan.sh` - extend the
  `isolation`/`worktree_path` prose in the output-schema header comment block; comment-only

**Verification**:
- `bash -n agent-system/extensions/core/scripts/orchestrate-cycle-plan.sh` exits 0 (confirms no
  edit crossed out of the comment region — the `prose`-tier blind spot this tier closes).
- `git diff` on this file shows only lines whose content begins with `#`.
- The header now contains an explicit never-an-Agent-tool-argument statement and a pointer to
  Move 2 by section name.
- Row-emission logic is byte-identical: `git diff` touches neither row builder nor
  `task_selected_for_worktree_isolation()`.

---

### Phase 3: Cross-link the design record to the point-of-use rule [NOT STARTED]

**Goal**: The "Deliberate Divergences" bullet that argues against a harness-level isolation
parameter points at the enforced rule in Move 2, and names the complementary failure mode it does
not itself cover, so a future edit to either surfaces the other.

**Tasks**:
- [ ] Re-read `context/patterns/batch-orchestration-guardrails.md`'s `### Deliberate Divergences`
      subsection immediately before editing.
- [ ] Add one line to the "Script-provisioned worktrees, not a harness-level isolation parameter"
      bullet pointing to the enforced point-of-use rule in `skill-orchestrate/SKILL.md`'s Move 2
      (by section name).
- [ ] Note in the same line that the stacked-worktree / cross-checkout-git-refusal /
      uncommittable-work failure mode is the complementary rationale carried there, distinct from
      this bullet's own `specs/`-staleness argument.
- [ ] Leave the existing `specs/`-staleness argument fully intact — add, never replace.
- [ ] Commit this file's hunk alone with an explicit pathspec.

**Timing**: 15 minutes

**Depends on**: 1

**Verification Tier**: prose

**Scope Hypothesis**: One file, one bullet, additive only — the existing `specs/`-staleness
sentences are preserved verbatim. Confirm at implementation time by reading `git diff` for this
file: expect additions only and zero deletions within the "Script-provisioned worktrees" bullet.

**Files to modify**:
- `agent-system/extensions/core/context/patterns/batch-orchestration-guardrails.md` - add one
  cross-reference line to the `### Deliberate Divergences` bullet

**Verification**:
- `git diff` shows additions only; no line of the existing `specs/`-staleness rationale is removed
  or reworded.
- The link is stated by section name, with no line number and no task number.
- Following the pointer from Move 2 to this section and back again both resolve to real,
  correctly-named sections.

---

### Phase 4: Final gate verification [NOT STARTED]

**Goal**: The full gate set is green across all three edits, with the task-reference lint and the
deploy-boundary rule both confirmed satisfied before the task closes.

**Tasks**:
- [ ] `bash .claude/scripts/check-task-references.sh` — confirm no task-number reference was
      introduced into any of the three edited files (all three live outside `specs/**`, so the
      prohibition applies to all of them).
- [ ] `bash -n agent-system/extensions/core/scripts/orchestrate-cycle-plan.sh` — re-confirm after
      all phases have landed.
- [ ] Confirm no file under `.claude/**` was written by any phase (`git status --short` plus a
      direct check), satisfying the source-store/deploy boundary.
- [ ] Re-read each of the three edited regions end to end and confirm the two-way pointers
      resolve: Move 2 -> "Deliberate Divergences", script header -> Move 2, "Deliberate
      Divergences" -> Move 2.
- [ ] Confirm `git log` shows this task's commits only in `agent-system/**`, with no foreign hunk
      swept in by an over-broad pathspec.
- [ ] Report the deploy tree as expectedly stale for these three files; do NOT regenerate it.

**Timing**: 20 minutes

**Depends on**: 1, 2, 3

**Verification Tier**: full

**Scope Hypothesis**: The gate set for a documentation-and-comment-only change in this source
store is the task-reference lint plus `bash -n` on the one edited shell script; no build, test
suite, or artifact validator is implicated because no executable line and no `specs/**` artifact
format changed. Confirm at implementation time by checking that the three edited paths are the
complete set of modified files attributable to this task in `git status --short`, and escalate to
the broader script-test suite only if that set turns out larger than three.

**Files to modify**:
- none planned (verification only)

**Verification**:
- `check-task-references.sh` reports no new violation.
- `bash -n` on `orchestrate-cycle-plan.sh` exits 0.
- Zero writes under `.claude/**`.
- Exactly the three intended source-store files are modified by this task's commits.

---

## Testing & Validation

- [ ] `grep -n -i "isolation" agent-system/extensions/core/skills/skill-orchestrate/SKILL.md`
      returns matches confined to the Move 2 section (was 0 matches before this task).
- [ ] The new Move 2 paragraph contains all five required content elements: categorical rule,
      Context-is-prompt-text note, `isolation`/`worktree_path` named example, one-clause
      consequence, forward pointer.
- [ ] `bash -n agent-system/extensions/core/scripts/orchestrate-cycle-plan.sh` exits 0.
- [ ] `orchestrate-cycle-plan.sh`'s executable body is unchanged (diff confined to `#` lines).
- [ ] `bash .claude/scripts/check-task-references.sh` reports no new violation across the three
      edited files.
- [ ] No file under `.claude/**` was created or modified.
- [ ] All three cross-pointers resolve to real, correctly-named sections in both directions.
- [ ] Each phase's commit stages only that phase's own file, by explicit pathspec.

## Artifacts & Outputs

- `agent-system/extensions/core/skills/skill-orchestrate/SKILL.md` — one new `**MUST NOT**:`
  paragraph in Move 2 (Phase 1).
- `agent-system/extensions/core/scripts/orchestrate-cycle-plan.sh` — strengthened
  `isolation`/`worktree_path` documentation in the output-schema header comment (Phase 2).
- `agent-system/extensions/core/context/patterns/batch-orchestration-guardrails.md` — one
  cross-reference line in `### Deliberate Divergences` (Phase 3).
- `specs/278_forbid_agent_isolation_forwarding_in_move_2/summaries/01_*-summary.md` — execution
  summary at implementation postflight.
- Three scoped commits, one per content phase.

## Rollback/Contingency

Each phase is a single-file, additive documentation edit committed independently, so the
contingency for any one phase is `git revert` of that phase's commit alone — no cross-phase
coupling, and reverting Phase 2 or Phase 3 leaves Phase 1's point-of-use rule (the core fix)
standing on its own. Phases 2 and 3 only reference Phase 1 by section name; reverting Phase 1
while keeping them would leave two dangling pointers, so a full rollback reverts in reverse order
(3, 2, 1).

Before any rollback that would discard uncommitted work, follow `context/contracts/recovery.md`'s
rollback rung for the exact `git-snapshot.sh` invocation shape, including its out-of-scope
override flag for the deliberate whole-tree case. Do not emit a bare default-mode
`git-snapshot.sh` as a routine start-of-phase checkpoint; an ordinary defensive checkpoint before
risky work uses `--no-revert` instead. Sibling tasks are editing this same working tree this
cycle, so a reverting whole-tree operation is especially inappropriate here — prefer a targeted
`git revert` of this task's own commits.

If the co-owning decomposition task lands first and relocates the `orchestrate-cycle-plan.sh`
header, Phase 2 re-derives the note's placement in the new layout rather than reverting; the
contingency is a location change, not an abandonment.
