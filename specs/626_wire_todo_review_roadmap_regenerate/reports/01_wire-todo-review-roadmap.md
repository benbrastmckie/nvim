# Research Report: Task #626

**Task**: 626 - Wire /todo and /review to roadmap regeneration behind the shared preflight gate
**Started**: 2026-11-15T00:07:00Z
**Completed**: 2026-11-15T00:21:00Z
**Effort**: medium
**Dependencies**: 625 (completed), 436 (completed), 458 (completed)
**Sources/Inputs**: Codebase (agent-system/extensions/core source store), specs/state.json
**Artifacts**: - this report
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- **The dispatch's own blocker rationale is stale.** Both external-dependency tasks it names
  (436, 458) are now `completed`, not `not_started`. Checking what they actually did changes
  one of the two wiring targets:
  - Task 436 did **not** retire `/review` or introduce `/orient` — it extended `/review` in
    place with a `--brief` mode. `commands/review.md` is still the correct, live wiring target
    exactly as the dispatch assumed.
  - Task 458 **fully removed `skills/skill-todo/SKILL.md`**. `commands/todo.md` is now the
    sole, direct-execution `/todo` implementation. The dispatch's DELIVERABLE 1 instruction to
    wire `skills/skill-todo/SKILL.md` names a file that no longer exists — the correct wiring
    target is `commands/todo.md`. (`context/patterns/roadmap-update.md`'s own current "Live
    Callers" section already says "Neither `/todo` (`commands/todo.md`) ... invokes this
    script", i.e. it already names the post-consolidation path, not the stale one.)
- **Deliverable 3's framing needs correction, not just an answer.** `--regenerate` is not
  actually a postflight-phase call in either command, because neither `commands/todo.md` nor
  the main flow of `commands/review.md` ever delegates to a subagent via the Agent tool.
  `context/standards/postflight-tool-restrictions.md`'s base tables, and its enforcement script
  `lint-postflight-boundary.sh`, are scoped to agent-delegating `SKILL.md` files only (confirmed
  by the lint's default scan path and its internal "does this skill delegate to a subagent"
  gate). The ruling is: **neither call site is bound by the base postflight tables, and neither
  needs the Move-5-style additive exception** — both should be wired as a plain, named step in
  each command's own existing direct-execution stage sequence, using the *interactive*
  `AskUserQuestion` preflight arm (the same arm `skill-roadmap/SKILL.md` Stage 1 already uses),
  not the autonomous degrade-loudly arm Move 5 uses.
- Recommended concrete insertion points: `commands/todo.md` gets a new stage after Stage 6's
  archival commit (mirroring Stage 6.5's "run after commit, as its own separately-scoped
  commit" shape already established for the repo-metrics sync); `commands/review.md` gets a new
  section immediately before/alongside Section 7's Git Commit, with its own separately-scoped
  `specs/ROADMAP.md`-only commit.
- `context/patterns/roadmap-update.md`'s "Live Callers" section and "Ruling" paragraph both need
  rewriting to list four live callers (two existing, two new) and to drop the
  "acknowledged gap... deliberately left unwired" framing, which this task settles.

## Context & Scope

Researched: (1) the current, post-consolidation shape of `/todo` and `/review`'s command files
to find the correct wiring target and insertion point for each; (2) the shared preflight
library `scripts/lib/roadmap-preflight-lib.sh` and its two existing consumers
(`skill-roadmap/SKILL.md`'s interactive arm, `context/contracts/conclusion-stage.md`'s
non-interactive arm) as the two patterns to choose between for the new call sites; (3) whether
`context/standards/postflight-tool-restrictions.md` actually governs either new call site, and
if so how; (4) whether the two blocking dependency tasks (436, 458) actually resolved the way
the dispatch's EXTERNAL DEPENDENCY RATIONALE assumed they would.

Out of scope (per the dispatch's CO-BATCH / ORDERING NOTE): tasks 492 and 503 touch
`commands/review.md` and `context/standards/postflight-tool-restrictions.md` respectively; these
are file-territory overlaps to batch/order around in the implementation phase, not duplicates,
and this report does not convert them into dependency edges.

## Findings

### Codebase Patterns

**Dependency resolution has changed the premise, not the plan.** `specs/state.json` shows
`project_number: 626`'s `dependencies: [625, 436, 458]`, and all three are `status: "completed"`:

- Task 625 (`roadmap_preflight_approval_gate`, completed) delivered exactly the shared library
  this task is told to source: `agent-system/extensions/core/scripts/lib/roadmap-preflight-lib.sh`,
  exposing `roadmap_preflight_classify PATH` (returns `absent|unknown|classic|stage`) and
  `roadmap_preflight_scaffold PATH` (writes the mechanical classic skeleton; refuses on
  `classic`/`stage`), both runnable sourced or as a script (`bash lib/roadmap-preflight-lib.sh
  classify|scaffold PATH`).
- Task 436's own artifact summaries record it extended `/review` in place (new `--brief` mode,
  read-only `scout-agent`) rather than retiring it for a new `/orient` command. Confirmed live:
  `agent-system/extensions/core/commands/review.md` exists; no `orient.md` exists anywhere under
  `agent-system/extensions/core/commands/`.
- Task 458's own artifact summaries record it removed `skill-todo` entirely (not thin-delegated)
  and made `commands/todo.md` the sole authoritative `/todo` implementation, flagging — in its
  own follow-ups — "task 626's stale `file_scope` reference" to the now-deleted skill file.
  Confirmed live: `agent-system/extensions/core/skills/skill-todo/` does not exist;
  `agent-system/extensions/core/commands/todo.md` does (886 lines).

Task 626's own `file_scope` (`specs/state.json`) still lists
`agent-system/extensions/core/skills/skill-todo/SKILL.md` — this is the exact stale reference
458 flagged. The correct edit target for the research/plan/implement phases is
`agent-system/extensions/core/commands/todo.md`.

**Both commands are direct-execution, not agent-delegating, in the flow this task touches.**
`grep -n -i "agent\|subagent"` over `commands/todo.md` returns zero Agent-tool/subagent_type
hits — its entire numbered flow (Stages 1-7, including Stage 6 "Git Commit" and Stage 6.5 "Sync
Repository Metrics") is plain Bash/jq/state-write.sh work, with no delegation boundary at all.
`commands/review.md`'s **main** flow (Sections 2-8: gather context, analyze, write report, task
proposal mode, registries, commit, output) is likewise direct execution with no subagent
dispatch. Its only subagent dispatch is Section 1.1's `--brief` early-exit mode (dispatches
`scout-agent`, "Mutually exclusive with `--create-tasks`... returns early") — a branch that
never reaches the Git Commit section this task's wiring targets.

**The two existing patterns for the preflight gate, and which one each new caller should use:**

1. *Interactive arm* (`skill-roadmap/SKILL.md` Stage 1): classify first; on `classic`/`stage`,
   proceed with no question; on `absent`/`unknown`, a single `AskUserQuestion` approval to
   create/repair, writing the scaffold (`roadmap-preflight-lib.sh scaffold`) only on approval,
   and stopping cold (no dispatch, no write) on decline.
2. *Non-interactive arm* (`context/contracts/conclusion-stage.md` Step 5, `/orchestrate`'s
   autonomous conclusion stage): classify first; on `classic`/`stage`, proceed as normal; on
   `absent`/`unknown`, **skip** `--regenerate` entirely (never auto-scaffolds — "this stage has
   no approver for it"), degrade loudly via an `events-append.sh` record plus a best-effort
   `issue-record.sh` loop, and let the next interactive `/roadmap` resolve it.

Both `/todo` and `/review` already carry `AskUserQuestion` in their command frontmatter's
`allowed-tools` list (confirmed: `agent-system/extensions/core/commands/todo.md` line 3;
`agent-system/extensions/core/commands/review.md` line 3) and both run as interactive,
user-invoked slash commands in a live session — the same shape `/roadmap` is in, not the shape
`/orchestrate`'s autonomous conclusion stage is in. **Both new call sites should use the
interactive arm**, not the non-interactive degrade arm: there is a user present to ask.

**Concrete insertion points** (for the plan phase to size, not performed in this research
dispatch):

- `commands/todo.md`: insert a new stage after Stage 6's archival
  `git-commit-scoped.sh` commit and before (or alongside) Stage 6.5's "Sync Repository Metrics".
  Stage 6.5 already establishes the exact shape to mirror — "run after Step 6's commit, not
  before it" (so the regenerate reads state `/todo` has already committed, same rationale
  `assess-repo-health.sh`'s sequencing note gives) and "its own narrowly-scoped commit, separate
  from Step 6's archival commit" (same `--honest-index-rows`/`--task` inapplicability reasoning
  Stage 6.5.3 already states, since a roadmap-regenerate commit also has no single owning task
  number). A `Stage 6.6: Regenerate Roadmap` (classify -> AskUserQuestion on absent/unknown ->
  `--regenerate` -> its own `specs/ROADMAP.md`-only commit) fits this slot directly.
- `commands/review.md`: insert a new section immediately before Section 7's existing Git Commit
  (which currently stages review artifacts + state + TODO.md in one commit) — give the roadmap
  regenerate its own separately-scoped `specs/ROADMAP.md`-only commit rather than folding it
  into Section 7's existing multi-path commit, matching the "Roadmap update: `specs/ROADMAP.md`
  only" row in `conclusion-stage.md`'s own Commit Surface table.

### External Resources

Not applicable — this is a pure codebase/contract-consistency task with no external
documentation dependency.

## Recommendations

1. **Wire `commands/todo.md`** (not `skills/skill-todo/SKILL.md`, which no longer exists) to
   `roadmap-integration.sh --regenerate`, sourcing `scripts/lib/roadmap-preflight-lib.sh`'s
   `classify` entry point, gated by the **interactive** `AskUserQuestion` arm
   (`skill-roadmap/SKILL.md` Stage 1's exact approval-question shape, reworded for `/todo`'s own
   context), at a new stage positioned after Stage 6's archival commit and before/alongside
   Stage 6.5, with its own separately-scoped `specs/ROADMAP.md`-only commit.
2. **Wire `commands/review.md`** to the same script via the same library, same interactive arm,
   positioned immediately before Section 7's existing Git Commit, with its own separately-scoped
   `specs/ROADMAP.md`-only commit (do not fold it into Section 7's existing multi-path commit).
   This wiring applies only to the command's main flow — the mutually-exclusive `--brief`
   early-exit path (Section 1.1) returns before reaching this point and needs no change.
3. **Rewrite `context/patterns/roadmap-update.md`'s "Live Callers" section** to list four live
   callers instead of two, each with its interactive-vs-autonomous arm named explicitly:
   - `/orchestrate`'s conclusion stage (Move 5, Step 5) — non-interactive arm (unchanged).
   - `roadmap-agent.md`'s Write Contract, dispatched by `skill-roadmap/SKILL.md` — interactive
     arm (unchanged).
   - `/todo` (`commands/todo.md`) — **new**, interactive arm.
   - `/review` (`commands/review.md`) — **new**, interactive arm.
   Replace the sentence "Neither `/todo` ... nor `/review` ... invokes this script" (now false)
   and retire the "Ruling" paragraph's "acknowledged gap... deliberately left unwired" framing —
   this task is the concrete operational need that paragraph said to wait for.
4. **Deliverable 3 ruling (recorded under Decisions below)**: do not add a Move-5-shaped
   additive exception section to `context/standards/postflight-tool-restrictions.md` for either
   call site — neither is governed by that standard's base tables in the first place. Instead,
   add one short clarifying sentence to that standard's Overview stating its base tables (and
   `lint-postflight-boundary.sh`'s enforcement) are scoped to agent-delegating `SKILL.md` files,
   so a future reader does not re-derive (or mis-apply) the same question this dispatch raised.
5. Before editing, re-run `grep -rl 'roadmap-preflight-lib.sh' agent-system/extensions/core` (the
   consumer-discovery command the library's own header recommends) to pick up the two new
   consumers once added — keeps the library's "single source of truth" self-description honest.

## Decisions

- **Deliverable 3, recorded ruling**: `context/standards/postflight-tool-restrictions.md`'s base
  Allowed/Prohibited tables do not apply to either `/todo`'s or `/review`'s new call site.
  Evidence: (a) `lint-postflight-boundary.sh`'s default scan path is `.claude/skills` and
  `.claude/extensions` `SKILL.md` files only — it never scans `.claude/commands/*.md`; (b) its
  own violation-detection logic explicitly gates on "Check if a skill delegates to a subagent"
  and skips files that don't; (c) neither `commands/todo.md`'s full flow nor `commands/
  review.md`'s main flow (the one this task's wiring touches) ever dispatches a subagent via the
  Agent tool, so there is no delegated-agent-work boundary for a postflight phase to protect in
  the first place; (d) neither file currently references
  `context/standards/postflight-tool-restrictions.md` at all, while every current consumer of
  that standard (grepped repo-wide) is an agent-delegating implementation skill, `skill-meta`,
  `skill-orchestrate`, `skill-reviser`, or `skill-spawn`. Conclusion: the call site is
  **postflight-legal as written, by virtue of being out of that standard's scope**, not because
  it already appears on an allowed-operations list — and it does **not** need the narrowly-scoped
  additive exception the Move 5 conclusion-stage table carries, because neither command has the
  structural "distinct, later actor running after delegated work closed" shape that justified
  that exception for Move 5. The precedent the standard itself sets for extending its reach to a
  new kind of actor is an explicit, named additive section (as Move 5 got) — not silent default
  coverage — and this task's plan/implement phases should follow that same precedent if a
  clarifying scope sentence is added to the Overview, rather than writing a second
  Move-5-shaped table that regulates nothing currently enforced.
- **File-scope correction**: this task's `file_scope` entry
  `agent-system/extensions/core/skills/skill-todo/SKILL.md` is stale (file no longer exists,
  per task 458). The plan/implement phases should edit `agent-system/extensions/core/commands/
  todo.md` instead. (This report does not edit `specs/state.json`'s `file_scope` itself —
  descriptive/anticipated per `state-management.md`, not filesystem-validated, and out of a
  research dispatch's remit — but the plan phase should account for the corrected path.)
- **`/review`'s `--brief` mode is out of scope for this wiring**: it is a mutually-exclusive,
  early-exit read-only path (dispatches `scout-agent`, never reaches Section 7's Git Commit), so
  no roadmap-regenerate call is added there.

## Risks & Mitigations

- **Risk**: wiring `/todo`'s roadmap-regenerate call before Stage 6.5's metrics sync could
  reintroduce the same "measuring a worktree the run is about to change again" hazard Stage 6.5's
  own header note already fixed once for `assess-repo-health.sh`. **Mitigation**: site the new
  stage after Stage 6's commit (as recommended above), consistent with Stage 6.5's own
  established ordering rationale, not before it.
- **Risk**: folding the `specs/ROADMAP.md` write into `/review`'s existing Section 7 commit (or
  `/todo`'s existing Stage 6 commit) would blur a renderer-owned file's commit history with an
  unrelated commit's `stage_paths`. **Mitigation**: give both new call sites their own
  separately-scoped `specs/ROADMAP.md`-only commit, as both the Move 5 Commit Surface table and
  `/todo`'s own Stage 6.5.3 precedent already do for an analogous repo-wide, non-task-scoped
  write.
- **Risk**: a future reader re-litigating whether `postflight-tool-restrictions.md` governs a
  command file (as this dispatch itself did) could re-derive the wrong answer without the
  clarifying scope sentence recommended above. **Mitigation**: add that sentence during the
  implementation phase alongside the `roadmap-update.md` rewrite, rather than leaving the
  boundary implicit.

## Context Extension Recommendations

None — this is a `meta` task; the relevant contract documentation gaps are already captured
above as concrete Recommendations/Decisions rather than a separate context-file gap.

## Appendix

### Search queries / commands used

- `jq`/`python3 -c` reads of `specs/state.json` for task 626's `dependencies`, `file_scope`,
  and tasks 436/458/492/503's `status`/`title`/`artifacts`.
- `grep -rl 'roadmap-preflight-lib.sh' agent-system/extensions/` — consumer discovery.
- `grep -n -i "agent\|subagent\|Tool: Agent"` over `commands/todo.md` and `commands/review.md`.
- `grep -rl "postflight-tool-restrictions"` repo-wide — consumer discovery for the standard.
- Direct reads: `scripts/lib/roadmap-preflight-lib.sh`, `context/patterns/roadmap-update.md`,
  `context/standards/postflight-tool-restrictions.md`, `context/contracts/conclusion-stage.md`
  (Step 5 excerpt), `skills/skill-roadmap/SKILL.md` (Stages 1 and 4), `commands/todo.md`
  (Stages 5.8-7), `commands/review.md` (Section 1.1, Section 7, frontmatter), `scripts/lint/
  lint-postflight-boundary.sh` (header + scan-path logic).

### References

- `agent-system/extensions/core/scripts/lib/roadmap-preflight-lib.sh`
- `agent-system/extensions/core/context/patterns/roadmap-update.md`
- `agent-system/extensions/core/context/standards/postflight-tool-restrictions.md`
- `agent-system/extensions/core/context/contracts/conclusion-stage.md`
- `agent-system/extensions/core/skills/skill-roadmap/SKILL.md`
- `agent-system/extensions/core/commands/todo.md`
- `agent-system/extensions/core/commands/review.md`
- `agent-system/extensions/core/scripts/lint/lint-postflight-boundary.sh`
- `specs/458_consolidate_duplicated_todo_implementation/summaries/01_consolidate-todo-implementations-summary.md`
- `specs/436_orient_command_with_scout_agent_retire_review/plans/01_review-strategic-brief-scout.md`
