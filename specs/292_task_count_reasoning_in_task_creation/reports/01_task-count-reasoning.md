# Research Report: Task #292

**Task**: 292 - Add task-count reasoning step to task creation
**Started**: 2026-10-01T00:00:00Z
**Completed**: 2026-10-01T00:00:00Z
**Effort**: TBD
**Dependencies**: None
**Sources/Inputs**: - Codebase (agent-system/extensions/core source store), git history (commit 5b82b685f)
**Artifacts**: - specs/292_task_count_reasoning_in_task_creation/reports/01_task-count-reasoning.md
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- `.claude/docs/reference/standards/multi-task-creation-standard.md` is already the single
  reference every multi-task creator points to (`commands/meta.md`, `commands/fix-it.md`,
  `commands/errors.md`, and `commands/task.md`'s `--review` mode all cite it explicitly). It is
  the correct, lowest-cost place to add the new consolidation-versus-division test, rather than
  editing four files independently.
- The existing "Task Minimization Principle" and Component 3 clustering (`/meta` Stage 3.5
  AnalyzeConsolidation, `/fix-it` Step 7.5) group by fuzzy **key-term / component-type /
  affected-area** overlap, not by the sharper signals the task description names (shared edit
  target, shared acceptance gate). That is why the near-miss happened: two findings governed by
  the exact same config file and the exact same verify-deploy gate are not guaranteed to share
  2+ key terms or the same `component_type`.
- `commands/task.md`'s **Create Task Mode** (single-description path, Steps 1-9) has no
  reference to the multi-task-creation-standard at all and no step asking "is this one task or
  several" — confirmed by direct inspection of its numbered Steps. This is the path any ad hoc
  multi-finding drafting (including the batch-postflight follow-up-task creation that motivated
  this task) actually walks, one description at a time, with no shared gate.
- The division direction has the identical gap: `commands/task.md`'s **Expand Mode** (`--expand`,
  line 371 ff.) Step 2 is "Analyze description for natural breakpoints... Create 2-5 subtasks" —
  no named criteria (file_scope disjointness, task_type/domain difference, dependency ordering,
  size) are stated anywhere in that step.
- `errors.md` has zero grouping/consolidation logic today (the standard's own compliance table
  marks it "Partial*" with "No" in every grouping/dependency/ordering column), so it inherits the
  gap most severely among the three named commands.
- `context/patterns/batch-orchestration-guardrails.md`'s "Batching Is the Default" section
  already argues the sibling point for how already-created tasks are **run** together
  (file-territory collision visibility across a dispatch batch); it says nothing about how many
  tasks should be **created** in the first place, which is exactly the gap this task closes.

## Context & Scope

Task 292 asks for an explicit task-count reasoning step — a named consolidation-versus-division
test — to be added to task creation, because `commands/task.md`'s Create Task Mode and the
multi-finding creators (`/meta`, `/fix-it`, `/errors`) currently default to one-task-per-finding
with no step that asks whether a set of findings is better expressed as one task or several. The
motivating incident: a batch postflight pass surfaced two findings that both edited
`agent-system/extensions/core/context/config/orchestrator-context-budget.json` and both resolved
the same verify-deploy gate (gate 20); drafting them as two tasks would have produced overlapping
`file_scope` declarations, which the system's own in-batch `file_scope_collision` check would
then have deferred one task behind the other — a self-defeating split, since the two "tasks"
were never independently dispatchable in the first place.

This research was scoped to: (1) locating every current task-creation code path (single- and
multi-task) and reading its actual steps verbatim rather than assuming the documented component
table is current; (2) locating the counterpart "division" logic (Expand Mode) to confirm it has
the same gap, since the task asks for a bidirectional test; (3) confirming the relationship to
`batch-orchestration-guardrails.md`'s existing run-time batching argument, which the task
explicitly says is the sibling point for a different question (how tasks are *run*, not how they
are *created*). All reads were against the source store (`agent-system/extensions/core/`), per
`.claude/rules/source-store-deploy-boundary.md` — this repo's deployed `.claude/` tree is
currently stale for the `core` extension (noted in the dispatch's deploy-freshness context), so
the deployed copies were not used as ground truth.

## Findings

### Codebase Patterns

**1. `multi-task-creation-standard.md` is the shared reference point, already wired to all four
consumers.**
- `commands/meta.md:12`, `commands/errors.md:205`, `commands/fix-it.md:282`, and
  `commands/task.md:888` (the `--review` mode) each contain a verbatim "This command/mode
  implements the multi-task creation pattern. See
  `.claude/docs/reference/standards/multi-task-creation-standard.md`" pointer.
- The standard already states a "Task Minimization Principle" ("Fewer, well-scoped tasks are
  better than many fragmented ones") and an 8-component checklist, with Component 3 ("Topic
  Grouping") as the existing consolidation mechanism.
- **Gap**: Component 3's clustering key is fuzzy — "same `file_section` AND same `issue_type`"
  or "2+ shared `key_terms` AND same `priority`" (`multi-task-creation-standard.md:102-116`).
  Nothing in the standard names "shares an edit target" or "resolves the same acceptance gate"
  as a standalone, sufficient consolidation criterion. The task's own motivating incident is
  precisely a case where two findings shared *one file* and *one gate* but might not have shared
  2+ generic key terms or an identical `file_section`+`issue_type` pairing — the near-miss was
  caught by ad hoc agent judgment during that specific postflight pass, not by this mechanism.
- Component 4a ("File Footprint Capture and Overlap Detection", lines 195-251) runs the
  **overlap-to-dependency** check, not an overlap-to-consolidation check: when two *already
  separate* proposed tasks' `file_scope` arrays overlap, it adds a serializing dependency edge
  between them rather than asking whether they should be one task. This is exactly the
  "self-defeating split" the task description flags: the system has a mechanism that reacts to
  file overlap between tasks, but only after division has already been decided, and only by
  serializing rather than by questioning the division itself.

**2. `commands/task.md` Create Task Mode (the single-description path) has no task-count
reasoning step and no reference to the multi-task-creation-standard.**
- Verified by reading the full numbered Steps 0-9 (`commands/task.md:38` onward): Step 0
  (bootstrap), Step 1 (read `next_project_number`), Step 2 (parse description), Step 3 (improve
  description — slug expansion, verb inference, formatting), Step 4 (detect `task_type`), Step
  4.5 (assign topic), Step 5 (create slug), Step 6 (update state.json). None of these steps ask
  "is the input one task or several" — the mode's contract (`## CRITICAL: $ARGUMENTS is a
  DESCRIPTION, not instructions`, lines 12-24) treats the single invocation as always producing
  exactly one task entry.
- This is the path any ad hoc multi-finding drafting actually uses when it is not routed through
  `/meta`'s interactive interview: a session (or an orchestrating agent, as in the motivating
  incident) that has N findings and calls task-creation logic N times, or writes N `state.json`
  entries directly following this mode's pattern, gets no prompt at any point to ask whether N is
  the right count. `/errors`' documented rationale for skipping interactive selection
  ("intentional for quick error triage", `multi-task-creation-standard.md:463`) makes this gap
  most visible there, but the *mechanism* gap — no task-count test exists anywhere upstream of
  per-item task assembly — is shared by any caller of the Create Task Mode pattern, not only
  `/errors`.

**3. The division direction (Expand Mode, `--expand`) has the identical shape of gap.**
- `commands/task.md:371-432` ("Expand Mode"). Step 2: "Analyze description for natural
  breakpoints (use DESCRIPTION exported by gate-in)." Step 3: "Create 2-5 subtasks using the
  Create Task jq pattern for each, inheriting parent topic."
- No criteria are named anywhere in this mode for *when* a task should be divided: not
  file-scope disjointness, not task_type/domain difference, not a real dependency ordering
  requirement, not a size bound. The subtask count (2-5) is an arbitrary range, not a derived
  consequence of any stated test. `context/standards/task-management.md:117-119` documents an
  inline `--expand` creation-time variant ("Refactor system: update commands, fix agents, improve
  docs" -> 3 tasks) delegating to a "task-divider" component, but no `task-divider` agent or
  skill file exists in the source store (confirmed: `find agent-system/extensions/core
  -iname "*task-divider*"` returns nothing) — this appears to be stale/aspirational documentation
  rather than a currently implemented path, and should not be treated as prior art for the
  division-side test the task description asks for.
- This confirms the task's request to "apply the same test to the division direction too" lands
  on real, currently-ungoverned code (Expand Mode Step 2), not a hypothetical concern.

**4. `batch-orchestration-guardrails.md` is a sibling concern about running tasks, not creating
them — confirmed, not merely assumed.**
- Its "Batching Is the Default" section (`context/patterns/batch-orchestration-guardrails.md:11`
  onward) is scoped to `/orchestrate N[,N-N]` dispatch of **already-created, already-numbered**
  tasks: "Shared file territory > topic cohesion > graph shape (width)" governs which open tasks
  to include in one `/orchestrate` invocation so that collision-visibility checks (creation-time
  overlap, runtime wave/cycle-split, lock acquisition) can see related tasks together.
- `commands/orchestrate.md` itself contains no task-creation logic (grep for "create.*task|new
  task|spawn.*task|follow-up" returns nothing) — confirming that when an orchestrating session
  drafts follow-up tasks from postflight findings (as in the motivating incident, commit
  `5b82b685f`), it is not following any documented procedure specific to that moment; it is
  improvising against the general Task Minimization Principle and whatever judgment the agent
  applies in the moment. Task 292's fix — a named, explicit test in the shared standard — is
  exactly what would make that moment stop depending on improvisation.

**5. The motivating incident was a near-miss, not an uncorrected defect.**
- The task entry actually created for the motivating finding pair (`project_number: 289`,
  `clear_orchestrator_context_budget_gate`, in commit `5b82b685f`) already states: "Both of the
  gate's open findings are governed by the single config file
  `agent-system/extensions/core/context/config/orchestrator-context-budget.json`, so they are one
  change, not two" — i.e., the consolidation was in fact applied in that instance, by ad hoc
  judgment at drafting time, not by any mechanical test. This matches the task description's
  counterfactual phrasing ("they would have declared overlapping file_scope... so the split was
  not merely cosmetic but actively self-defeating") — describing a split that was caught and
  avoided, which is precisely the kind of outcome that should not depend on an individual
  drafting agent noticing it each time.

**6. `/meta` and `/fix-it` already have *some* consolidation machinery; `/errors` has none.**
- `agents/meta-builder-agent.md:453-602` (Interview Stage 3.5, AnalyzeConsolidation) implements
  the clustering algorithm referenced above, user-facing via an `AskUserQuestion` picker.
- `skills/skill-fix-it/SKILL.md:203-244` implements the equivalent "topic_groups" clustering for
  both TODO and QUESTION items, likewise with a user-facing grouped/separate/combined picker, and
  its own Step 8.2 Component-4a overlap check (lines 331-341) layered after grouping.
- `commands/errors.md` has no grouping logic at all (confirmed by grep: no "consolidat|group
  |cluster" hits), consistent with `multi-task-creation-standard.md`'s own compliance table
  marking it "Partial*" and explaining the omission is "intentional for quick error triage" —
  the standard's own "Gaps and Future Enhancements" section (lines 478-481) already names this as
  an open enhancement (`--interactive` flag), separate from the consolidation-test gap this task
  addresses.

### External Resources

Not applicable — this is a `meta` task about this repository's own agent-system source store;
no external documentation or best-practice research applies. All findings are codebase-internal.

## Recommendations

1. **Add the new test as a component in `multi-task-creation-standard.md`, not duplicated across
   four command files.** Insert it as an early, named component — e.g. "Component 0: Task-Count
   Reasoning" immediately before "Component 1: Item Discovery," or as a substantially expanded
   "Task Minimization Principle" section — stating the default and the exhaustive divide/
   consolidate reason lists from the task description:
   - **Default**: consolidate unless a named divide reason applies.
   - **Legitimate reasons to divide**: genuinely disjoint `file_scope` (no overlap), different
     `task_type` or owning domain, a real dependency ordering between the parts, or a size that
     will not fit one agent dispatch (cross-reference the phase-sizing bound named in
     `merge-sources/claudemd.md`'s Hard Mode section, H8: "~100-500 lines output" per phase/run).
   - **Reasons NOT to divide**: findings that share an edit target (same file(s)) or share a
     single acceptance gate belong in one task — this is the sharper, file/gate-keyed test the
     existing fuzzy key-term clustering (Component 3) does not capture, and is the specific
     signal the motivating incident turned on.
   - State explicitly that this test is bidirectional: apply it when fragmenting (consolidate
     findings that share a target/gate) and apply it when a single task has grown oversized
     (still split when size or domain genuinely calls for it, per the same divide-reason list).
   - Explicitly cross-reference `context/patterns/batch-orchestration-guardrails.md`'s "Batching
     Is the Default" section as the sibling point for how already-created tasks are *run*
     together, distinguishing it from this component's concern (how many tasks to *create* in
     the first place) — exactly as the task description requests, so a future reader is not
     left to infer the boundary.

2. **Wire `commands/task.md` Create Task Mode into the new component**, since it is the common
   path every ad hoc multi-finding drafter (including a batch-postflight follow-up-task session
   with no dedicated skill file) actually walks. A natural insertion point is between current
   Step 2 ("Parse description") and Step 3 ("Improve description"): a short step directing the
   caller — when drafting more than one task from a related set of findings/observations in the
   same session — to run the Component 0 test before assigning each finding its own description,
   with a pointer to `multi-task-creation-standard.md` rather than restating the test inline.

3. **Wire `commands/task.md` Expand Mode Step 2 into the same component**, replacing "Analyze
   description for natural breakpoints" with a reference to the divide-reason list, so the
   2-5-subtask range becomes a consequence of applying the named test rather than an unexplained
   bound. This closes the division-direction half of the task's ask using the same source of
   truth, avoiding a second, drifting copy of the criteria.

4. **Sharpen `/meta` Stage 3.5 and `/fix-it` Step 7.5's existing clustering to add file/gate
   sharing as a primary-match criterion**, not only as the already-separate Component 4a overlap
   check. Currently file-scope overlap is only consulted *after* grouping decisions are made
   (to add a serializing dependency between resulting tasks); promoting "shares a file in
   `file_scope`" or "resolves the same gate/check" to a primary clustering match (alongside the
   existing `component_type`+`affected_area` and key-term criteria) would have caught the
   motivating incident mechanically rather than by ad hoc judgment.

5. **Treat `/errors`' total absence of grouping as in-scope for this task's "same gap" framing**,
   per the task description's explicit naming of `/errors`, even though the standard's own
   compliance table currently excuses this as intentional. The planning phase should decide
   whether closing this gap means giving `/errors` the same Component 0 test (lightweight —
   stating the default and the divide reasons even in automatic/non-interactive mode) without
   necessarily adopting full interactive grouping (that remains the separate, already-tracked
   `--interactive` enhancement).

6. **Do not relocate or restate `batch-orchestration-guardrails.md`'s "Batching Is the Default"
   content.** It correctly covers a different moment in the lifecycle (run-time batch selection
   of existing tasks). The fix here is a cross-reference between the two documents, not a merge.

## Decisions

- **Scope confirmed**: this task's fix belongs in `multi-task-creation-standard.md` as the
  canonical location, with pointers added from `commands/task.md` (both Create and Expand
  modes). It does not require changes to `batch-orchestration-guardrails.md` itself beyond
  possibly an inbound cross-reference note.
- **The `--expand`-mode "task-divider" delegation mentioned in `context/standards/task-management.md`
  is stale/unimplemented** (no such agent or skill exists in the source store) and must not be
  cited as existing prior art for the division-side test; the plan phase should treat Expand Mode
  Step 2 as currently ungoverned, matching the task description's framing.
- **The motivating incident (task 289) was a correctly-resolved near-miss**, not an uncorrected
  defect requiring its own remediation; no action is needed on task 289 itself. This task's scope
  is purely the systemic fix (the missing reasoning step), consistent with the dispatch
  description.

## Risks & Mitigations

- **Risk**: adding a new mandatory reasoning step could slow down `/errors`' intentionally fast,
  non-interactive triage path. **Mitigation**: scope the `/errors` change (Recommendation 5) to a
  lightweight, non-interactive application of the default-to-consolidate rule (e.g., a mechanical
  pre-merge of findings sharing a file or gate before task entries are drafted) rather than
  importing `/meta`'s full interactive picker.
- **Risk**: duplicating the test's wording across `multi-task-creation-standard.md`,
  `commands/task.md` (twice), `meta-builder-agent.md`, and `skill-fix-it/SKILL.md` risks drift.
  **Mitigation**: keep the full test (default + reason lists) in exactly one place
  (`multi-task-creation-standard.md`) and have every other file reference it by path, matching
  the existing convention all four current consumers already use for the standard itself.
- **Risk**: sharpening Component 3's clustering to add file/gate-sharing as a primary match could
  over-consolidate genuinely independent findings that happen to touch a shared, widely-edited
  file (e.g., `state.json` itself). **Mitigation**: the new criterion should be "shares a
  *narrow* file-scope entry or a single named acceptance gate," not "shares any file," and the
  plan phase should explicitly exclude broad/shared infrastructure files from triggering
  automatic consolidation (consistent with `validate-state.sh` Check 8's existing WARN-only
  treatment of coarse, directory-root `file_scope` entries).

## Context Extension Recommendations

None — this is a `meta` task; the relevant documentation gap (no task-count reasoning step in
`multi-task-creation-standard.md`) is the subject of the task itself and will be closed by its
own implementation phase rather than requiring a separate context-extension task.

## Appendix

**Search queries / commands used**:
- `grep -n "consolidat\|group\|cluster\|one task\|separate task" commands/errors.md
  skills/skill-fix-it/SKILL.md`
- `grep -rln "batch postflight" agent-system/extensions/core`
- `git show 5b82b685f -- specs/state.json` (motivating-incident task entries 289/290)
- `grep -rln "file_scope_collision|file-footprint-overlap" agent-system/extensions/core`
- `grep -n "divide\|split\|expand" context/standards/task-management.md`
- `find agent-system/extensions/core -iname "*task-divider*"` (confirmed absent)
- `grep -n "multi-task-creation-standard|Task Minimization" commands/meta.md commands/fix-it.md
  commands/errors.md commands/task.md`

**Key files read in full or by targeted section**:
- `agent-system/extensions/core/commands/task.md` (Create Task Mode Steps 0-9; Expand Mode lines
  371-447; `--review` mode Standards Reference, line 888)
- `agent-system/extensions/core/docs/reference/standards/multi-task-creation-standard.md` (entire
  file)
- `agent-system/extensions/core/context/patterns/batch-orchestration-guardrails.md` (lines 1-70,
  "Batching Is the Default" section)
- `agent-system/extensions/core/agents/meta-builder-agent.md` (lines 453-602, Stage 3.5
  AnalyzeConsolidation)
- `agent-system/extensions/core/skills/skill-fix-it/SKILL.md` (lines 203-420, grouping/overlap)
- `agent-system/extensions/core/context/standards/task-management.md` (lines 100-170)
- `agent-system/extensions/core/merge-sources/claudemd.md` (Hard Mode / H8 phase-sizing, line 182)
