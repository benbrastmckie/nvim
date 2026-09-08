# Research Report: Task #150

**Task**: 150 - Research on demand: planner-first lifecycle with research only when the planner asks or --research forces it
**Started**: 2026-09-08T06:31:00Z
**Completed**: 2026-09-08T06:36:00Z
**Effort**: N/A (research only)
**Dependencies**: Task 88 (completed — deleted the single-task engine; the thin four-move loop is now the only engine)
**Sources/Inputs**: Codebase read of the 10 `file_scope` files, `specs/PATH.md` (Stage A.8, Decisions #7), `specs/state.json` task record
**Artifacts**: - this report
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- The binding DESIGN in the task description is implementable with **zero new files and no
  schema/enum additions beyond one new status token** — every mechanism it needs (a focus-string
  injection channel, a "researching"-equivalent resting state, a file-scope-style state.json
  write-back pattern, an existing `researching -> research` classifier row) already exists in the
  four-move engine built by Task 88, mostly unused or reused from an adjacent purpose.
- **Critical hazard found**: if a planner returns `dispatch_status: "needs_research"` without
  `orchestrate-cycle-postflight.sh` gaining a dedicated case arm, the status falls into the
  existing catch-all (`orchestrate-cycle-postflight.sh:683-712`), which sets
  `offschema_dispatch_status=true`, verdict=`failed`, **`halt=true`, and records an
  `OFF_SCHEMA_STATUS` system defect**. That is the single most consequential fact for the plan:
  it directly contradicts the task's own MUST NOT ("record nothing as a defect") and would abort
  the whole `/orchestrate` invocation on the very first `needs_research` verdict, not just defer
  the one task.
- `orchestrate-build-dispatch.sh` already accepts a `--focus "<text>"` flag (line 118) that (a)
  is appended to the dispatch file under `User focus: ...` (line 342-344) and (b) is threaded
  into `memory-retrieve.sh` as the third arg **only when `phase == "research"`** (line 205). It
  has **zero callers today** — grep across `agent-system/extensions/` found no site passing
  `--focus`. This is exactly the channel design point (b) needs to carry the planner's question
  list into the research dispatch; it needs a caller, not a new mechanism.
- `orchestrate-triage-classify.sh` already has a `researching -> research` row (used today only
  for a task stranded mid-session by a dead lock). Landing the planner's `needs_research` verdict
  as state `researching` (rather than reverting to `not_started`) means the **classifier needs NO
  new row at all** — it is Decision (c)'s "[RESEARCHING]-equivalent" option, and it is the one
  that requires zero classifier changes.
- `update-task-status.sh`'s existing `--file-scope-add` write-back (a postflight-only,
  research-specific flag that additively merges `proposed_file_scope` from `.return-meta.json`
  into the task's `file_scope`, wired through `skill-base.sh:skill_postflight_update`'s
  `_fsa_args` pattern, `skill-base.sh:686-696`) is a byte-for-byte structural template for the
  new "carry the planner's questions forward" write-back this task needs — same file, same
  function, same call-site shape, different field name.

## Context & Scope

Task 150 is Stage A.8 of `specs/PATH.md`'s thin-lead rewrite, landing after Task 88 (which
deleted the single-task engine and rewrote `skill-orchestrate/SKILL.md` as the four-move loop:
Move 1 `orchestrate-cycle-plan.sh`, Move 2 dispatch, Move 3 `orchestrate-cycle-postflight.sh`,
Move 4 wrap-up). The task's own DESIGN section is binding on shape; only mechanics are open. This
research maps every DESIGN clause onto the concrete file/line the implementing plan will touch,
across all 10 `file_scope` entries, and surfaces the one correctness hazard a plan must design
around.

`file_scope` (from `specs/state.json`, task 150):
```
agent-system/extensions/core/agents/planner-agent.md
agent-system/extensions/core/context/formats/return-metadata-file.md
agent-system/extensions/core/context/standards/status-markers.md
agent-system/extensions/core/docs/architecture/orchestrate-state-machine.md
agent-system/extensions/core/scripts/orchestrate-cycle-plan.sh
agent-system/extensions/core/scripts/orchestrate-cycle-postflight.sh
agent-system/extensions/core/scripts/orchestrate-triage-classify.sh
agent-system/extensions/core/scripts/tests/test-orchestrate-cycle-plan.sh
agent-system/extensions/core/scripts/tests/test-orchestrate-cycle-postflight.sh
agent-system/extensions/core/scripts/tests/test-orchestrate-triage-classify.sh
```
All 10 exist on disk; none are missing. `agent-system/extensions/core/` is confirmed as the
source-store edit target (`.claude/**` is the disposable deploy artifact — see
`.claude/rules/source-store-deploy-boundary.md`).

## Findings

### Codebase Patterns

**1. Current default routing (`not_started -> research`)** is defined identically in three
places that must change together (the file's own header names this "one code path" contract):
- `orchestrate-triage-classify.sh:322-325` (the jq classifier: `elif $status == "not_started"
  then group="research"`)
- `orchestrate-triage-classify.sh:401-405` (the `blocked`-discharge re-routing table, which reuses
  the same not_started/researched/planned-or-implementing/researching/planning ladder against
  `previous_status`)
- `orchestrate-cycle-plan.sh:1064-1071` (the **degraded-classifier fallback**, used only when
  `orchestrate-triage-classify.sh` itself exits non-zero: `not_started|researching)
  triage_group[$t]="research"`). This fallback table must also flip to `plan` or the fallback
  path silently reintroduces the old default whenever the classifier script degrades.
- `docs/architecture/orchestrate-state-machine.md:25-26` (the "Complete State Table" — prose
  documentation of the same rule, explicitly listed as something Task 88 kept in sync with the
  scripts; both the `not_started` and `researching` rows currently read
  `dispatch(research, task_n)` and need updating to `dispatch(plan, task_n)` with a footnote for
  the `needs_research` fork).
- The ASCII "State Transition Diagram" a few lines below the table (lines ~87-104) draws
  `not_started -> dispatch research` as the left branch; it needs the same swap plus a new branch
  for the `needs_research` fork back to research.

**2. `researching` is a full first-class resting state already, not a marker that needs
inventing.** `status-vocabulary.sh` / `state-schema.json` (the closed enum status-markers.md
defers to) already include it; `update-task-status.sh`'s `map_status()` already emits it from
`preflight:research` (`update-task-status.sh:243`); and the classifier already routes it to
`research` (`orchestrate-triage-classify.sh` table row, `researching (NEW...) | research |
research`). Decision (c)'s "or [RESEARCHING]-equivalent" option requires **no new enum value,
no new classifier row, no new status-markers.md prose beyond noting the new producer** — only a
new *producer* of the `researching` state (see hazard below), because today the only way to reach
`researching` is `preflight:research`, and after this change a `needs_research` verdict must also
be able to land there, from `postflight`, without a status regression.

**3. The preflight-write ordering matters and creates the concrete mechanics gap.** When a
`not_started` task is classified into group `plan` under the new default,
`orchestrate-cycle-plan.sh:1477` calls `skill_preflight_update "$t" "plan" "$dispatch_session"`
**before** the planner agent runs, which (via `update-task-status.sh`'s `preflight:plan` row,
line 244) writes `status="planning"` to `state.json` immediately. So by the time the planner
agent decides it needs research and writes `needs_research` to its own `.return-meta.json`, the
task's `state.json` status is already `"planning"`, not `"not_started"`. Design point (c)'s "no
status regression" therefore cannot mean "leave it alone" — postflight must **actively write** a
new resting state once the planner returns `needs_research`, and the two states offered
(`not_started` or `researching`) are both numerically "behind" `planning` in the linear phase
order, though the state machine's permissive model (`state-management.md`: "Any non-terminal
status -> any command") already allows exactly this kind of non-monotonic write outside of
`--force`'s monotonic-max clamp path (`clamp_mode` is only ever set to `"monotonic-max"` when
`force_invoked=true`; an ordinary `needs_research` postflight write is not force-invoked, so no
clamp logic applies to it).

**4. `researching` is the mechanically cheaper of the two options in (c).** Landing on
`researching` reuses the existing classifier row verbatim (finding #2). Landing on `not_started`
would additionally require either a brand-new classifier row (there is currently no
`planning -> not_started` regression path anywhere) or overloading the existing `not_started`
row's semantics. No file in scope currently writes `not_started` after any other state — it is
exclusively an initial/creation-time value (`state-management.md`, task creation). Recommend
`researching` as the target state for the plan to adopt, stated as a finding, not a task-150
decision override (per the task's own "the planner of this task refines mechanics, not the
shape").

**5. `.return-meta.json` status enum and the postflight status ladder must both gain
`needs_research` as a peer of the existing six values, not a variant of `failed`/`partial`.**
- `return-metadata-file.md:23` currently documents:
  `"status": "researched|planned|implemented|partial|failed|blocked"` — this line is the schema
  source for the field `orchestrate-cycle-postflight.sh` reads as `dispatch_status`
  (`orchestrate-cycle-postflight.sh:408,473,559`, `jq -r '.status // ""'` off the handoff or
  return-meta). It needs `|needs_research` appended.
- `orchestrate-cycle-postflight.sh`'s status-transition switch
  (`orchestrate-cycle-postflight.sh:628-712`) currently has arms for `researched`, `planned`,
  `implemented`, a combined `partial|failed|blocked` (no-op, log only), and a `*)` catch-all that
  is the off-schema-defect path described in the Executive Summary. A `needs_research)` arm must
  be inserted **before** the catch-all. Its job: call something that writes `researching` to
  `state.json` (see finding #6) and explicitly must NOT fall through to the catch-all's
  `offschema_dispatch_status=true` / `system-defect-record.sh --defect-class OFF_SCHEMA_STATUS`
  path (`orchestrate-cycle-postflight.sh:684-712`).
- The verdict-resolution switch (`orchestrate-cycle-postflight.sh:792-805`, vocabulary documented
  at the top of the file as `verdict ∈ ok|defer|blocked|failed|ask_user`) needs a `needs_research)`
  arm too. The task description's own phrase — "relay `needs_research` as a verdict" — reads most
  naturally as adding a **sixth verdict value**, `needs_research`, alongside the existing five
  (rather than overloading `defer`, which today means "in-flight, retry same phase next cycle" —
  semantically wrong here, since the phase changes from plan to research). This is a genuine
  small vocabulary extension the plan should make explicit in the file header comment at
  `orchestrate-cycle-postflight.sh:90`, matching the existing convention of documenting the
  verdict enum in that one place.

**6. No existing status-writing entry point produces `researching` from a `postflight` call.**
`skill_postflight_update()` (`skill-base.sh:647-731`) gates its call into
`update-task-status.sh postflight ...` on `case "$status" in researched|planned|implemented)`
(`skill-base.sh:684`); anything else just logs "Non-success status ... skipped" and performs no
write. `update-task-status.sh`'s own `map_status()` has no `postflight:*` arm that yields
`researching` (only `preflight:research` does, line 243). Two structurally sound options for the
plan to choose between (both consistent with existing conventions, listed as options — not
resolved here per the task's own scope boundary):
  - (A) Add a new `target_status` token, e.g. `needs_research`, to `update-task-status.sh`'s
    `map_status()`: `postflight:needs_research) STATE_STATUS="researching";
    TODO_STATUS="RESEARCHING"`, and extend `skill_postflight_update()`'s status whitelist
    (`skill-base.sh:684`) to also accept `"needs_research"` alongside
    `researched|planned|implemented`, calling `update-task-status.sh postflight "$task_number"
    "needs_research" ...`. This keeps the naming distinct from the pre-existing
    `preflight:research` producer of the same state value and is the more legible option.
  - (B) Re-invoke `update-task-status.sh preflight "$task_number" research "$session_id"`
    directly from the postflight script for this one case, bypassing `skill_postflight_update()`
    entirely. Mechanically simpler but semantically confusing (a "preflight" call issued from
    postflight code, for a phase that has not actually started).
  Recommend (A): it keeps every status-write call site inside skill-base.sh's existing
  postflight-only surface, matches the file-scope-add precedent (finding #7) of extending
  `skill_postflight_update()`'s optional-argument surface rather than routing around it, and its
  naming self-documents intent in a `git blame`/grep search.

**7. The write-back mechanism for carrying the planner's question list to the research dispatch
already has a structural precedent to copy: `--file-scope-add`.** Today, on a `research`
postflight only, `skill_postflight_update()` reads `proposed_file_scope` out of the just-completed
research agent's own `.return-meta.json` and forwards it as `--file-scope-add=<json>` to
`update-task-status.sh`, which additively merges it into the task's `file_scope` in `state.json`
(`skill-base.sh:686-696`; restriction enforced at `update-task-status.sh:214-218`,
`--file-scope-add is only valid with operation=postflight and target_status=research`). The same
shape — read a new field off `.return-meta.json` at the moment of the `needs_research` postflight,
forward it as a new flag, write it into a new durable `state.json` field on the task record (e.g.
`research_questions` or `research_focus`, an array or string) — is the natural way to get the
planner's question list from the planner's own return-meta (ephemeral: overwritten the next time
any agent's Stage 0 runs against this task) into `state.json` (durable across `/orchestrate`
invocations, unlike `mt_state_file`, see finding #8).

**8. `mt_state_file` is NOT a safe place to carry the question list.** It is explicitly minted
fresh every `/orchestrate` invocation (`orchestrate-cycle-plan.sh:49,371`: `mt_state_file="...
.orchestrator-multi-state-${session_id}.json"`, keyed by session_id). If the `needs_research`
verdict and the follow-up research dispatch happen to fall in two different `/orchestrate`
invocations (budget exhaustion, a crashed session, a manually re-run command on a later day), any
data stored only in `mt_state_file` is gone. `state.json` (task-record field, per finding #7) is
the only field-carrying location the plan should use for the question list; `--focus` (finding
below) is the read-time consumer.

**9. `orchestrate-build-dispatch.sh --focus` is unused plumbing built for exactly this.**
`--focus "<text>"` (`orchestrate-build-dispatch.sh:118`) is parsed but, per a repo-wide grep,
called from nowhere. Its two effects: appended into the dispatch file body as `User focus:
${focus_prompt}` right after the task Description (`orchestrate-build-dispatch.sh:341-344`), and
passed as the third positional arg to `memory-retrieve.sh` **only `if [ "$phase" = "research"
]`** (`orchestrate-build-dispatch.sh:204-205`) — i.e. it is already phase-gated to exactly the
phase this task needs it for. `orchestrate-cycle-plan.sh` (the sole caller of
`orchestrate-build-dispatch.sh`, at its live per-task dispatch loop around line 1477 onward — the
exact call site was not fully enumerated in this pass but is co-located with the
`skill_preflight_update` call already cited) needs to: read the task's new
`research_questions`/`research_focus` field from `state.json` when (and only when) building a
`research`-phase dispatch, join it into a single string, and pass `--focus "<joined
questions>"`. No change to `orchestrate-build-dispatch.sh` itself is required for this half.

**10. `resolve_agent()` in `orchestrate-cycle-plan.sh` (lines ~1258-1268) hardcodes
`planner-agent` for `op == "plan"` regardless of `task_type`,** unlike `research`/`implement`
which route through `command-route-agent.sh` for extension-specific agents (e.g.
`nix-research-agent`, `neovim-implementation-agent`). This matches `.claude/CLAUDE.md`'s
Skill-to-Agent table, where every task type (core and every loaded extension) maps to the same
`planner-agent` — there is no per-domain planner today. **Consequence for this task**: point (d)'s
"planner-agent.md (and extension planner agents, swept with negatives)" is address-space-empty as
written — a repo-wide check found no extension ships its own `*-planner-agent.md`; only the one
`agents/planner-agent.md` in core exists. The "swept with negatives" instruction should be
satisfied by grepping for any extension-declared planner agent at plan time and finding none,
rather than assuming one exists to edit.

**11. Existing fixture/test shape to extend.** `test-orchestrate-triage-classify.sh` builds
`state.json`-shaped JSON fixtures inline (e.g. line 224:
`{"project_number": 105, "project_name": "fixture_not_started", "status": "not_started"}`) and
asserts against the classifier's NDJSON output with a `fail` helper; there is a paired
"sandbox probe" pattern (single-engine, line ~97-107) and an "mt engine" pattern (line ~224-236)
that intentionally mirror each other so both engine code paths get the same fixture status
exercised. New fixtures for `researching` state produced by a `needs_research` verdict, and for
the `not_started -> plan` default, should follow this exact paired-fixture convention rather than
introducing a new fixture style. `test-orchestrate-cycle-plan.sh` and
`test-orchestrate-cycle-postflight.sh` were not read in comparable depth this pass (budget); the
plan's phase covering test changes should do a focused read of each file's existing "not_started"
and "researched" fixture cases as the direct template for the new "not_started->plan" and
"needs_research->researching+focus-carried" fixtures.

### External Resources

None consulted — this is a pure in-repo architecture task; no external API, library, or published
best-practice applies. (Per the general-research-agent's own strategy table, meta tasks route to
context files and codebase patterns first; that fully answered every open question here.)

### Recommendations

1. Treat `researching` (not `not_started`) as the resting state for a `needs_research` verdict —
   it is the only one of the two options in point (c) that requires zero classifier changes
   (finding #4).
2. Add `needs_research` as a sixth top-level value in three closed vocabularies that must move
   together: `.return-meta.json`'s `status` field (`return-metadata-file.md:23`), the postflight
   `dispatch_status` switch (`orchestrate-cycle-postflight.sh:628-712`, new arm before the
   catch-all), and the verdict enum documented at `orchestrate-cycle-postflight.sh:90-107`.
3. Give `skill_postflight_update()`/`update-task-status.sh` a `needs_research` target-status arm
   (Option A in finding #6) mapping to `STATE_STATUS="researching"`.
4. Add a `--research-focus`/`--file-scope-add`-shaped write-back so the planner's question list
   travels from `.return-meta.json` into a new durable `state.json` task field, structurally
   copying the existing `proposed_file_scope` -> `--file-scope-add` -> `file_scope` merge
   (finding #7); do not use `mt_state_file` for this (finding #8).
5. Wire `orchestrate-cycle-plan.sh`'s research-dispatch build call to read that new field and pass
   it through the already-built, already-phase-gated, currently-unused `--focus` flag on
   `orchestrate-build-dispatch.sh` (finding #9) — no changes needed inside
   `orchestrate-build-dispatch.sh` itself.
6. Flip the three `not_started -> research` sites in lockstep: the classifier's live jq logic, its
   degraded-classifier fallback table inside `orchestrate-cycle-plan.sh`, and the doc's state
   table + ASCII diagram (finding #1) — all four must change in the same phase to avoid a
   temporarily-inconsistent default.
7. Confirm at plan time (a fresh, cheap grep) that no extension ships its own planner agent before
   spending phase budget on a "sweep extension planner agents" step that may have zero targets
   (finding #10).
8. `--research` (phase-forcing) needs no new code: it already forces the `research` phase first
   via the pre-existing `force_phases_remaining` per-task queue (`orchestrate-cycle-plan.sh:33,
   1082-1102`), independent of the classifier's default row and independent of any
   `needs_research` machinery — the task's own MUST NOT ("skip research when `--research` is
   passed") is already satisfied by the existing force-phase mechanism and should be verified,
   not rebuilt.

## Decisions

None made unilaterally by this research pass — the task's DESIGN section is binding and the
planner is the one authorized to fix mechanics. The one place this report goes beyond pure fact
gathering is finding #4/#6 (recommending `researching` over `not_started`, and Option A over
Option B for the state-write mechanism); both are flagged as recommendations, not decisions, and
both are reversible by the plan without contradicting anything in this report.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| `needs_research` lands in the postflight catch-all and halts the whole `/orchestrate` run with a recorded defect | H | H (certain, if the new case arm is forgotten) | Explicit new `needs_research)` arm in the status-transition switch, placed and tested BEFORE the `*)` catch-all; a dedicated fixture in `test-orchestrate-cycle-postflight.sh` asserting `halt=false` and no `OFF_SCHEMA_STATUS` defect recorded |
| The three `not_started -> research` sites (classifier, degraded fallback, docs) drift out of sync, since two are jq/bash and one is prose | M | M | Land the flip in one phase, add a fixture pinning the degraded-fallback table specifically (the file's own header already calls the classifier "the one code path... never drift into two silently-diverging copies again" — extend that discipline to the fallback table, which the header does not currently mention) |
| Question-list write-back field grows unbounded across repeated `needs_research` cycles for a stubborn task | L | L | Design the field as overwrite-on-write (not append), same as `proposed_file_scope`'s union-merge target `file_scope` is additive but the *source* field itself is fully replaced each research postflight |
| Extension "sweep" step (point d) finds nothing and looks like a skipped requirement | L | M | Plan phase explicitly states "checked, none found" rather than silently omitting the step, per this report's finding #10 |

## Context Extension Recommendations

- **Topic**: postflight dispatch_status / verdict vocabulary
- **Gap**: `orchestrate-cycle-postflight.sh`'s header comment (lines 90-107) is the sole
  authoritative listing of the verdict enum; there is no separate context/standards doc cataloging
  it the way `status-markers.md` catalogs task-level statuses. Not a blocker for this task, but
  worth flagging since this task is the first to extend that enum since Task 88 landed it.
- **Recommendation**: no new context file needed for this task; if the verdict vocabulary grows
  again after this task, consider promoting the header-comment table to a short
  `context/standards/postflight-verdict-vocabulary.md` the way `status-markers.md` promotes the
  task-status enum.

## Appendix

### Files read in full or targeted-grep this pass
- `agent-system/extensions/core/agents/planner-agent.md` (full)
- `agent-system/extensions/core/context/formats/return-metadata-file.md` (schema section)
- `agent-system/extensions/core/context/standards/status-markers.md` (definitions + state table)
- `agent-system/extensions/core/docs/architecture/orchestrate-state-machine.md` (state table, ASCII diagram)
- `agent-system/extensions/core/scripts/orchestrate-cycle-plan.sh` (header, mt_state schema, classification/dispatch-candidate sections, resolve_agent)
- `agent-system/extensions/core/scripts/orchestrate-cycle-postflight.sh` (header/verdict vocabulary, status-transition switch, verdict-resolution switch)
- `agent-system/extensions/core/scripts/orchestrate-triage-classify.sh` (header table, jq classify logic)
- `agent-system/extensions/core/scripts/orchestrate-build-dispatch.sh` (arg parsing, --focus usage, dispatch file rendering)
- `agent-system/extensions/core/scripts/skill-base.sh` (`skill_postflight_update`, `_fsa_args` file-scope-add precedent)
- `agent-system/extensions/core/scripts/update-task-status.sh` (`map_status()`, `--file-scope-add` restriction)
- `agent-system/extensions/core/scripts/tests/test-orchestrate-triage-classify.sh` (fixture shape, targeted grep)
- `specs/PATH.md` (Stage A.8 row, Decisions #7, "After 150" validation note)
- `specs/state.json` (task 150's own record: file_scope, dependencies, status)

### Searches performed
- `grep -rn -- "--focus" agent-system/extensions/` — confirmed zero callers of the existing
  `--focus` flag.
- `grep -n "not_started\|researched\|force_phases\|needs_research"` across the three routing
  scripts — located every site implementing the current default and the force-phase mechanism.
- Repo-wide check for extension-declared planner agents (via the CLAUDE.md skill/agent mapping
  tables already in context) — none found beyond the single core `planner-agent.md`.

### Open questions for the plan (not answered here — genuinely mechanics, per task's own boundary)
- Exact new `state.json` field name for the carried question list (`research_questions` vs.
  `research_focus` vs. reusing a generic `pending_focus`).
- Whether the question list is stored as a JSON array (parallel to `file_scope`) or a single
  joined string (parallel to `--focus`'s own string shape) — storing as an array and joining at
  the `--focus` call site avoids a lossy round-trip if it is ever inspected structurally later.
- Whether `status-markers.md`'s prose (as opposed to the schema/enum files, which do not need a
  new value) needs a new subsection under `[RESEARCHING]` documenting the second producer
  (planner-declined-to-plan), or whether a cross-reference to
  `orchestrate-state-machine.md` suffices.
