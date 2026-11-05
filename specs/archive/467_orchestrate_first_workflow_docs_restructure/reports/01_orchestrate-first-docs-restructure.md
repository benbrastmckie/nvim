# Research Report: Task #467

**Task**: 467 - Restructure the user-facing agent system workflow documentation around an orchestrate-first spine
**Started**: 2026-11-03
**Completed**: 2026-11-03
**Effort**: medium
**Dependencies**: None (task 468 depends on this task, not the reverse)
**Sources/Inputs**: Codebase exploration (source-store docs, commands, scripts, state.json); no web search needed (purely internal documentation/architecture reconciliation)
**Artifacts**: specs/467_orchestrate_first_workflow_docs_restructure/reports/01_orchestrate-first-docs-restructure.md
**Standards**: report-format.md, subagent-return.md, source-store-deploy-boundary.md, documentation-policy.md, no-task-references-in-deliverables.md, no-record-versioning-in-deliverables.md

## Executive Summary

- Confirmed: `/research`, `/plan`, and `/implement` do not exist as commands anywhere under
  `agent-system/extensions/*/commands/`. `agent-system/extensions/core/commands/` contains exactly
  14 command files (errors, fix-it, merge, meta, orchestrate, please, project-overview, refresh,
  review, revise, spawn, tag, task, todo, zulip) plus README.md — no research.md/plan.md/implement.md.
- `agent-system/extensions/core/docs/guides/user-guide.md` (687 lines, "Last Updated: 2026-05-22")
  is built end-to-end on the dead per-phase surface: its Quick Start, Core Workflow Commands
  section (/task, /research, /plan, /revise, /implement subsections), Status Progression table,
  Command Summary Table, Status Transitions diagram, and Language Routing table all cite
  `/research N`, `/plan N`, `/implement N [--force]` as standalone invocable commands. The
  `/orchestrate` treatment is a ~40-line stub (lines ~402-441) covering only bare `/orchestrate N`
  and a "10 states" model.
- `agent-system/extensions/core/docs/guides/user-installation.md` (327 lines) independently
  teaches the same dead cycle in its "Setting Up Claude Agent Commands" section (lines ~108-141):
  an Available Commands table listing `/research`/`/plan`/`/implement` as if they exist.
- `agent-system/extensions/README.md`'s "Available Extensions" table (line ~22) lists 17
  extensions and omits four that exist as real directories: `books`, `cslib`, `email`,
  `literature` (confirmed via `ls agent-system/extensions/`; all four directories exist with their
  own `README.md`/`manifest.json` and a `task_type` field).
- `docs/examples/research-flow-example.md` (444 lines) is **already retargeted** at
  `/orchestrate {N} --research` — it is not, contrary to the dispatch framing, still built on the
  removed command surface. However it violates `rules/no-record-versioning-in-deliverables.md`
  throughout (an inline "supersedes an earlier version... both were retired" sentence, a "used to
  carry here" clause, a parenthetical "were deleted" aside, and a "Document Version: 3.0 (Updated
  ... after the standalone `/research` command ... were deleted)" footer). See Decision below —
  this changes outcome 6's required action from retarget-or-retire to strip-the-versioning-prose.
- Record 435's `file_scope` was already amended at task-creation time (confirmed via
  `specs/state.json`): it no longer lists `agent-system/extensions/core/docs/`. Acceptance
  criterion "Record 435's file_scope no longer claims core/docs/" is **already satisfied** —
  implementation needs no action on this point, only verification.
- Task 328 (status `planned`) still lists `agent-system/extensions/core/docs/` in its own
  `file_scope` (confirmed), corroborating the dispatch's collision-advisory framing: no dependency
  edge should be added, this is pre-existing visible overlap only.
- `scripts/lint/lint-dead-command-recommendations.sh` currently passes clean (`--quiet` exit 0, no
  output) against the whole `agent-system/extensions` corpus. It only flags a literal
  `Next:`/`Run` recommendation line naming an undefined command — it does not itself require
  removing the Core Workflow Commands prose, but any rewritten doc must avoid introducing a new
  `Next: /research N` or `Run /plan N` style line.

## Context & Scope

Scope: the five files named in the dispatch's REQUIRED OUTCOMES — `user-guide.md`,
`extensions/README.md`, `docs-README.md` (link addition only), `user-installation.md`, and
`research-flow-example.md` — all under the source store
(`agent-system/extensions/core/docs/` and `agent-system/extensions/README.md`), never under
`.claude/**` directly (`rules/source-store-deploy-boundary.md`). Constraint confirmed:
`source_dir` for the `core` extension resolves to
`/home/benjamin/.config/nvim/agent-system/extensions/core` per `.claude-extensions.json`.

This research dispatch did not write or edit any of these files — it verified the dispatch's
factual claims against the current repository state and gathered the concrete line-range/content
detail a plan needs to scope phases precisely. Deep reads of the full authoritative-source files
(`orchestrate-state-machine.md`, `handoff-schema.md`, `batch-admit-schema.md`,
`orchestrate-cycle-postflight.md`, `batch-orchestration-guardrails.md`,
`multi-task-operations.md`, `status-markers.md`) were not exhaustive; their existence and the
cited subsections were confirmed, but the planner/implementer should read each in full when
drafting the corresponding `/orchestrate` doc sections, since this report summarizes only enough
to scope the work, not to author the final prose.

## Findings

### Codebase Patterns

**Command inventory** (`agent-system/extensions/core/commands/`): errors, fix-it, merge, meta,
orchestrate, please, project-overview, refresh, review, revise, spawn, tag, task, todo, zulip,
README.md. No research/plan/implement command file exists in this directory or in any other
extension's `commands/` directory — `/orchestrate` (with `--research`/`--plan`/`--implement`
forcing flags) is the sole lifecycle driver, matching `CLAUDE.md`'s own Command Reference table.

**`user-guide.md` stale regions** (verified against the live 687-line file):
- Table of Contents (lines 11-34): lists `/research`, `/plan`, `/revise`, `/implement` as
  "Core Workflow Commands" subsections.
- Quick Start (lines 38-77): the cycle diagram `/task "Description" -> /research N -> /plan N ->
  /implement N -> /todo`, plus a numbered "Your First Workflow" walkthrough invoking each as a
  standalone command.
- Status Progression table (lines 78-95): maps `[RESEARCHING]`/`[RESEARCHED]`/`[PLANNING]`/
  `[PLANNED]`/`[IMPLEMENTING]`/`[COMPLETED]` to "After Command" values of `/research`, `/plan`,
  `/implement` — omits `[HOLD]`, `[PR READY]`, `[BLOCKED]`, `[PARTIAL]` (only lists them loosely
  as "Exception statuses").
- `### /task Command` through `### /implement Command` (lines ~168-290): full per-command
  subsections with argument tables and examples for `/research N [focus]`, `/plan N`,
  `/revise N [reason]`, `/implement N [--force]`.
- `### /orchestrate Command` (lines ~402-441): documents only `/orchestrate N` (no batch syntax,
  no forcing flags, no effort/model/lit/hard/clean/fast flags, no cycle budgets); the "10 states"
  state-machine description is a simplification that predates the current richer per-task cycle
  model in `orchestrate-state-machine.md`.
- Command Summary Table (lines ~571-595) and Status Transitions diagram (~597-613): same
  per-phase-command framing, plus the diagram omits `[HOLD]`/`[PR READY]` entirely.
- Language Routing table (~615-624): present but was not independently audited for
  completeness against the current extension set in this pass — flag for implementation-time
  re-check.
- Confirmed omissions: `/project-overview`, `/please`, `/zulip` do not appear anywhere in
  `user-guide.md` (verified via `grep`), despite all three having real command definition files.

**`user-installation.md` stale region** (327 lines): "Setting Up Claude Agent Commands" section
(roughly lines 108-141) states "Structured Workflow: `/research` -> `/plan` -> `/implement`
cycle" and an "Available Commands" table listing `/research`/`/plan`/`/implement` as real
commands, pointing to `../commands/README.md` for "complete documentation." This needs the same
orchestrate-first retarget as `user-guide.md`, consistent with REQUIRED OUTCOME 7.

**`agent-system/extensions/README.md`** (151 lines): "Available Extensions" table (starts ~line
22) currently lists: nvim, lean, latex, typst, python, rust, nix, web, z3, epidemiology, formal,
filetypes, founder, present, memory, slidev, approvals — 17 rows. The actual extension directory
set (confirmed via `ls agent-system/extensions/`) is 21 directories: the 17 above plus **books,
cslib, email, literature**. Each of the four missing ones has its own `README.md` and a
`task_type` field in `manifest.json` (`books`, `cslib`, `email`; `literature` has no dedicated
`task_type` row in its manifest's routing in the same shape as the others — confirm at
implementation time whether it needs a "Task Type" column entry of "-" like `memory`/`slidev`/
`approvals`, which also show "-"). No file in `agent-system/extensions/core/` links to this
README; the load mechanism (`<leader>ac` Neovim / `<leader>ao` OpenCode) is documented only here.

**`docs-README.md`** (143 lines): has a `## Related Documentation` section (line 132) with
`### Core References` (134) and `### Project Documentation` (138) subsections — the natural
insertion point for the new Extensions-catalog link named in REQUIRED OUTCOME 4. Its `## Examples`
section (line 119) currently describes `research-flow-example.md` as "Complete walkthrough of the
research command execution flow" — slightly ambiguous phrasing worth tightening when outcome 6 is
applied (not itself a required outcome, but a low-cost consistency fix in the same file).

**`docs/examples/research-flow-example.md`** (444 lines): already traces
`/orchestrate {N} --research` through `skill-orchestrate`'s current architecture (Setup / Move 1 /
Move 2 / Move 3 terminology, `command-route-agent.sh` routing, `.return-meta.json` return flow).
The content itself is not built on the dead command surface. What IS wrong: four spans of
record-versioning language that violate `rules/no-record-versioning-in-deliverables.md`
(not exempt — this file sits under `agent-system/**`, not `specs/**`):
  1. Lines 5-6: "It supersedes an earlier version of this example that traced the now-deleted
     standalone `/research` command through the base lifecycle research skill — both were
     retired, and..."
  2. Line 79: "...used to carry here have all collapsed into this one call:"
  3. Line 442 (in the closing attribution block): "...base lifecycle research skill were
     deleted)"
  4. The "Document Version: 3.0 (Updated 2026-09-02 to retrace the flow through `/orchestrate`
     and `skill-orchestrate`'s direct agent dispatch, after the standalone `/research` command
     and the base lifecycle research skill were deleted)" footer line, directly below "Related
     Documentation."

**Record 435 / Task 328 cross-check** (via `jq` against `specs/state.json`):
- Project 435's `file_scope` array was inspected directly: it lists `agent-system/extensions/
  core/{README.md,agents/,commands/,context/,hooks/,index-entries.json,manifest.json,
  merge-sources/,root-files/,rules/,scripts/,skills/,templates/}` plus other extensions'
  directories — **no `agent-system/extensions/core/docs/` entry**. This confirms the amendment
  described in the dispatch already happened at task-creation time (the meta-builder-agent's own
  `.return-meta.json` for this task's creation batch states exactly this amendment). No further
  action needed for this acceptance item beyond leaving it alone.
- Project 328's `file_scope` DOES still list `agent-system/extensions/core/docs/` and its status
  is `planned` — confirms the dispatch's "COLLISION ADVISORY ONLY, no dependency edge" framing is
  accurate and current.

**Lint gate**: `scripts/lint/lint-dead-command-recommendations.sh` (and its deployed twin at
`.claude/scripts/lint/`) enumerates the valid-command set by walking
`agent-system/extensions/*/commands/*.md` (excluding README.md case-insensitively) and flags only
a literal `Next:`/`Run` line immediately followed by `/<name>` where `<name>` has no definition
file. Running it now (`bash .claude/scripts/lint/lint-dead-command-recommendations.sh --quiet`)
exits 0 with no output — the corpus is currently clean. The rewritten docs must not introduce a
new `Next: /research N`-shaped line; ordinary prose mentioning `/research`/`/plan`/`/implement`
historically (which the rewrite is removing anyway per outcome 1) is not itself what this lint
polices, but the safest compliant target is simply to not name those three as invocable commands
at all, which is what outcome 1 already requires.

### External Resources

Not applicable — this is a purely internal documentation-reconciliation task with no external
library/API dependency. No WebSearch/WebFetch was used.

## Recommendations

1. Treat the five files as one coordinated phase-plan, in this order to minimize rework:
   (a) `extensions/README.md` table fix (self-contained, no dependency on the others);
   (b) `user-guide.md` full rewrite (the largest, highest-risk file — do it with the
   `/orchestrate`-first spine and the preserved stepwise human-in-the-loop path per outcome 1);
   (c) `user-installation.md` alignment to match (b)'s terminology/spine);
   (d) `docs-README.md` one-link addition under `## Related Documentation` (depends on (a)'s
   final README existing, trivial ordering);
   (e) `research-flow-example.md` — strip the four record-versioning spans identified above;
   no retarget or retirement needed, contrary to the dispatch's framing of this as an
   either/or retarget-vs-retire decision.
2. For the `/orchestrate` first-class section in `user-guide.md`, read
   `agent-system/extensions/core/commands/orchestrate.md` in full (349 lines; this report read
   roughly the first third covering Arguments/Constraints/Options/Anti-Bypass/Stage 0) plus
   `docs/architecture/orchestrate-state-machine.md` for the forcing-flag admission rules
   (`--research` always admitted, `--plan` always admitted via planner-or-reviser-agent,
   `--implement` only when a plan artifact exists), before drafting — the Options table in
   `orchestrate.md` alone enumerates `--lit`, `--compare`, `--gate`, `--dry-run`,
   `--allow-self-modifying`, `--allow-scope-collision`, `--clean`, `--fast`, `--hard`, `--haiku`/
   `--sonnet`/`--opus`/`--fable`, `--research`/`--plan`/`--implement` — the plan should enumerate
   all of these, not just the four effort/context flags and model flags named in outcome 2's
   summary line.
3. For the preserved stepwise path (outcome 1's non-negotiable requirement), retarget the removed
   `### /task Command`, `### /research Command`, `### /plan Command`, `### /revise Command`,
   `### /implement Command` subsections as: `/task "Description"` (unchanged) ->
   `/orchestrate N --research` -> `/revise N` (to adjust the plan) ->
   `/orchestrate N --implement`. `/revise` itself is unaffected (still a real, standalone command)
   and keeps its own subsection.
4. For the Status Progression / Status Transitions sections, add `[HOLD]` and `[PR READY]`
   explicitly with their non-resumable / type-gated semantics (`[HOLD]` only liftable by an
   explicit `/orchestrate --research|--plan|--implement` override or an operator
   `update-task-status.sh ... unhold`; `[PR READY]` reachable only via `preflight:pr_ready` for
   `task_type == "pr"`, per `status-markers.md`'s "Target Arguments vs. Resting States"
   subsection) rather than lumping them into a generic "Exception statuses" aside as the current
   stub does for `[BLOCKED]`/`[ABANDONED]`/`[PARTIAL]`/`[EXPANDED]`.
5. Add `/project-overview`, `/please`, and `/zulip` as new subsections (or table rows plus short
   subsections) in whichever section of `user-guide.md` best fits each — `/project-overview` fits
   near `/task` (bootstrap), `/please` fits near `/merge` (user-only, push-adjacent), `/zulip` fits
   in Utility Commands near `/fix-it`.
6. Re-enumerate `agent-system/extensions/` directories at implementation time (do not trust this
   report's snapshot list verbatim) and add all missing rows to `extensions/README.md`'s table in
   one pass, including each one's actual `task_type` value from its `manifest.json`.
7. After all edits, redeploy via `deploy-headless.sh` using the bounded-wait idiom named in the
   dispatch (`timeout 540`, Bash tool timeout raised to 600000) to a clean `verify-deploy.sh`,
   per the dispatch's explicit instruction never to hand-patch `.claude/**` in place of a
   redeploy.

## Decisions

- **research-flow-example.md**: neither retarget (already done) nor retire. The correct action
  is a targeted strip of the four record-versioning-language spans identified above, leaving the
  current-architecture content intact. This report's own framing differs from the dispatch's
  binary retarget-or-retire choice (this report, under `specs/**`, is exempt from the
  record-versioning-language rule that governs the deliverable itself); the plan should record
  this decision explicitly rather than re-deriving it.
- No dependency edge is added between task 467 and task 328, consistent with the dispatch's
  explicit instruction; the file_scope collision is accepted as an advisory-only artifact of a
  batched dispatch.
- Record 435's file_scope amendment required no further action in this task; it was already
  applied at task-creation time and was only re-verified here.

## Risks & Mitigations

- **Risk**: Rewriting `user-guide.md`'s ~250-line Core Workflow Commands section risks
  accidentally dropping the human-in-the-loop stepwise path entirely (deleting rather than
  retargeting), which the dispatch explicitly forbids. **Mitigation**: treat retargeting, not
  deletion, as the literal edit operation for each of the five removed-command subsections —
  rename the heading and rewrite the invocation line, keep the surrounding explanatory prose
  about what each step produces.
- **Risk**: `extensions/README.md`'s table fix could drift again if a future extension is added
  without updating the table (no current CI gate checks this). **Mitigation**: out of scope for
  this task (no new lint requested), but worth flagging in the plan's Context Extension
  Recommendations.
- **Risk**: Redeploy step (`deploy-headless.sh`) could be slow or hang. **Mitigation**: dispatch
  already specifies the bounded-wait idiom (`timeout 540`, Bash tool timeout 600000); the
  implementation phase must follow `context/patterns/bounded-build-waiter.md` exactly (captured
  PID, `kill -0` liveness loop) rather than `run_in_background`/Monitor.
- **Risk**: The relative-link acceptance check across the five touched files could break if link
  paths are copied without adjusting for each file's directory depth (e.g. `../README.md` from
  `docs/guides/` vs. a sibling link from `docs/`). **Mitigation**: verify each inserted link
  resolves relative to its own file's directory, not copy-pasted from a different file's
  perspective.

## Context Extension Recommendations

- **Topic**: Extension-table staleness detection.
- **Gap**: Nothing currently checks `extensions/README.md`'s "Available Extensions" table against
  the real `agent-system/extensions/*/` directory set; this is exactly the staleness this task is
  fixing by hand. No context file documents this as a known gap today.
- **Recommendation**: a future lint (`lint-extension-readme-table.sh` or similar) enumerating
  extension directories and diffing against the README table's first column would prevent this
  drift recurring; not in scope for this task, but worth a follow-up task note.

## Appendix

### Search queries / commands used
- `jq -r '.extensions.core.source_dir' .claude-extensions.json`
- `ls agent-system/extensions/core/commands/`
- `wc -l agent-system/extensions/core/docs/guides/user-guide.md agent-system/extensions/README.md`
- `grep -n "project-overview\|/please\|/zulip" agent-system/extensions/core/docs/guides/user-guide.md`
- `grep -n -i "previously\|no longer\|formerly\|used to\|supersede\|retired\|deleted\|removed\|was replaced" agent-system/extensions/core/docs/examples/research-flow-example.md`
- `jq -r '.active_projects[] | select(.project_number==435) | .file_scope' specs/state.json`
- `jq -r '.active_projects[] | select(.project_number==328) | {status, file_scope}' specs/state.json`
- `bash .claude/scripts/lint/lint-dead-command-recommendations.sh --quiet`

### References
- `agent-system/extensions/core/commands/orchestrate.md` (349 lines; Arguments/Constraints/
  Options/Anti-Bypass/Stage 0 read in full)
- `agent-system/extensions/core/docs/guides/user-guide.md` (687 lines)
- `agent-system/extensions/core/docs/guides/user-installation.md` (327 lines)
- `agent-system/extensions/README.md` (151 lines)
- `agent-system/extensions/core/docs/docs-README.md` (143 lines)
- `agent-system/extensions/core/docs/examples/research-flow-example.md` (444 lines)
- `agent-system/extensions/core/scripts/lint/lint-dead-command-recommendations.sh`
- `.claude-extensions.json`, `specs/state.json`
