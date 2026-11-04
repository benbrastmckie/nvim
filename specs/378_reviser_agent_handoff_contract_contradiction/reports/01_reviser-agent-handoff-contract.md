# Research Report: Task #378

**Task**: 378 - Resolve the reviser-agent handoff contract contradiction between skill-orchestrate and orchestrate-cycle-plan.sh
**Started**: 2026-11-04T17:18:37Z
**Completed**: 2026-11-04T18:05:00Z
**Effort**: small (doc + agent-contract edits only; no script changes required)
**Dependencies**: 274
**Sources/Inputs**:
- Codebase: `agent-system/extensions/core/agents/reviser-agent.md`, `agents/planner-agent.md`,
  `skills/skill-orchestrate/SKILL.md`, `scripts/orchestrate-cycle-plan.sh`,
  `scripts/orchestrate-cycle-postflight.sh`, `docs/architecture/handoff-schema.md`,
  `scripts/tests/test-orchestrate-cycle-plan.sh`
**Artifacts**:
- This report: `specs/378_reviser_agent_handoff_contract_contradiction/reports/01_reviser-agent-handoff-contract.md`
**Standards**: report-format.md, subagent-return.md, source-store-deploy-boundary.md (source store
is the edit target for any follow-on implementation: `agent-system/extensions/core/**`, never
`.claude/**`)

## Executive Summary

- The hypothesis in the task description is **confirmed**: `reviser-agent` is dispatched by two
  genuinely different call paths with different `orchestrator_mode` values, and only one of them
  is documented or honored by the agent's own contract.
- Path 1 (`aux_dispatch[]`, "Plan revision (blocker/drift)"): `orchestrator_mode: false`, no
  `handoff_path` key at all. Correctly documented everywhere and correctly never writes a handoff.
- Path 2 (`dispatch[]`, ordinary/forced "plan" phase when `resolve_agent()` finds an existing
  `plans/*.md` for the task): `orchestrator_mode: true`, `handoff_path` supplied by Move 2's
  generic per-row template — **identical treatment to a `planner-agent` plan dispatch**. This path
  is exercised by `--force-phases plan` on a task that already has a plan, and is the one the
  task's `--- EVIDENCE ---` observed in BimodalLogic (dispatch_seq 5).
- `agents/reviser-agent.md` has no `.orchestrator-handoff.json` section at all (confirmed by a
  full read of the file) — it only writes `{task_dir}/.plan-revised.json` (Stage 5c) and
  `.return-meta.json` (Stage 6), regardless of which path dispatched it. So on Path 2 it silently
  skips a handoff it was never told to write.
- `orchestrate-cycle-postflight.sh`'s own design (its "D1: dispatch-derived handoff expectation
  (no agent-name list)" comment block) treats **every** `dispatch[]` row as handoff-expected by
  construction, deliberately with no agent-name allowlist. This design is sound in general but
  collides with `resolve_agent()`'s artifact-based admission rule for the `plan` operation, which
  can route a `dispatch[]` "plan" row to either `planner-agent` or `reviser-agent` depending on
  whether `plans/*.md` already exists for the task — a distinction the postflight script's
  comment does not acknowledge.
- `docs/architecture/handoff-schema.md`'s own "Handoff Writers" table (the authoritative,
  single-source-of-truth list per its own header) lists only `planner-agent` for the plan phase,
  explicitly **excluding** `reviser-agent` — so the schema doc already (correctly, if
  incompletely) treats `reviser-agent` as a non-writer, while the postflight script's dispatch-
  derived design treats it as one. This is the actual seat of the contradiction: not a bug in the
  dispatch mechanics (which are deliberate and test-pinned), but a gap in `reviser-agent.md`'s own
  write contract that the schema doc's writer table never flagged as a gap.
- Recommended direction: **(a)** — give `reviser-agent` the same conditional,
  `orchestrator_mode`-gated handoff-writing contract every other writer already has (mirroring
  `planner-agent.md`'s own section verbatim), rather than **(b)** (reclassifying the dispatch),
  because (b) would require adding exactly the per-agent exception that `orchestrate-cycle-
  postflight.sh`'s own design comment explicitly argues against, and because the dispatch
  mechanics choosing `reviser-agent` for an existing-plan "plan" dispatch[] row are intentional,
  documented, and pinned by existing tests (Group 23 Cases C and E in
  `test-orchestrate-cycle-plan.sh`).

## Context & Scope

Verify, against `agents/reviser-agent.md` and both call paths, whether a `reviser-agent` plan
dispatch is contractually required to write `.orchestrator-handoff.json`; determine which of two
candidate fixes to pursue; and confirm the fix is consistent with `docs/architecture/handoff-
schema.md` if the contract text lives there too. Per the task's own "SOURCE STORE IS THE EDIT
TARGET" instruction, all file paths below are given relative to `agent-system/extensions/core/`
(the source store a future `/orchestrate 378 --plan`/`--implement` round must edit), not the
deployed `.claude/` mirror.

## Findings

### Codebase Patterns

**Call Path 1 — `aux_dispatch[]` ("Plan revision (blocker)" / "(drift)")**

- `scripts/orchestrate-cycle-plan.sh:1461` maps `plan-revision -> "reviser-agent"` for this kind,
  and both row-builders (`:1472`, `:1529`) emit it with `orchestrator_mode: false` hardcoded into
  the row shape — never `true` on this path.
- `skills/skill-orchestrate/SKILL.md`'s Move 2 (`:174-182`) documents the `aux_dispatch[]` loop
  explicitly: `orchestrator_mode: false, ... } — NO handoff_path key at all: an aux dispatch
  never writes .orchestrator-handoff.json.`
- Move 2's own `MUST NOT` (`:185-188`) reinforces that an `aux_dispatch[]` row never reaches Move
  3 (postflight) at all — so this path can never trigger a `HANDOFF_STALE_OR_ABSENT` defect
  regardless of what the agent writes.
- The Skill-to-Agent Mapping table's rows 385/387 ("Plan revision (blocker)" / "(drift)") document
  exactly this path and are accurate for it.

**Call Path 2 — `dispatch[]` ("plan" phase, artifact-based admission)**

- `scripts/orchestrate-cycle-plan.sh`'s `resolve_agent()` (`:2167-2186`) has a dedicated `plan)`
  case, documented by the header comment at `:2115-2122` as "Phase 5 (artifact-based plan
  admission)": *"plan is always admitted; which agent depends only on whether `plans/*.md`
  already exists ... never a status check."* If an existing plan file is found
  (`ls "${_ra_task_dir_abs}/plans/"*.md`), it returns `"reviser-agent"`; otherwise
  `"planner-agent"`. This is explicitly called out as bypassing `command-route-agent.sh` entirely
  for the `plan` op.
- `resolve_agent()` is called from exactly two sites, both of which feed the shared `dispatch[]`
  row builder (`out_dispatch_rows`), never `aux_dispatch[]`: the `--dry-run` rendering loop
  (`:2370`) and the live per-task dispatch loop (`:2732`).
- `skills/skill-orchestrate/SKILL.md`'s Move 2 `dispatch[]` loop (`:162-173`) is **generic across
  every phase and every resolved agent** — its template comment unconditionally sets
  `orchestrator_mode: true` and `handoff_path: "${task_dir_abs}/.orchestrator-handoff.json"` for
  **every** row in `dispatch[]`, with no agent-name branching anywhere in Move 2's code or prose.
  A `dispatch[]` row whose `agent` field happens to be `"reviser-agent"` (because an existing plan
  was found) gets identical `orchestrator_mode: true` / `handoff_path` treatment to a
  `planner-agent` row.
- This exact path is what the task's `--- EVIDENCE ---` section describes: `--force-phases plan`
  on a task that already has a plan resolves to `reviser-agent` via this artifact-based rule, is
  built into `dispatch[]` (not `aux_dispatch[]`), and so reaches Move 3/postflight carrying
  `orchestrator_mode: true`.
- This path is deliberate and test-pinned, not an accident: `scripts/tests/test-orchestrate-cycle-
  plan.sh` Group 23 Case C (`:3378-3396`, "`--plan` with an existing plan resolves reviser-agent")
  and Case E (`:3443-3446`, "terminal (completed) task with a plan still resolves reviser-agent
  when forced") both assert `.dispatch[...].agent == "reviser-agent"` for this exact scenario.

**`agents/reviser-agent.md` — confirmed gap**

- A full read of the file's Stages 0-7 and both "MUST DO"/"MUST NOT" lists in "Critical
  Requirements" (`:183-206`) turned up **zero** mentions of `.orchestrator-handoff.json`,
  `orchestrator_mode`, or `handoff_path` anywhere in the file.
- The only durable, cross-dispatch signal it writes is `{task_dir}/.plan-revised.json` at Stage 5c
  (`:113-124`), explicitly scoped as "the only routine signal that tells a live implement dispatch
  its plan file just changed underneath it" — a different sentinel, for a different consumer
  (a concurrently-live implement dispatch), not a substitute for the orchestrator-handoff contract.
- Because the file has no `orchestrator_mode`-conditional branch at all, it behaves identically on
  both call paths: write `.return-meta.json`, write `.plan-revised.json` (plan-revision mode only),
  return a text summary. On Path 2 this means it silently omits a handoff its own dispatch context
  asked for.

**`orchestrate-cycle-postflight.sh` — the detection side**

- Receives `--agent "$agent"` from Move 3's call site (`SKILL.md:215`; script stores it as
  `agent_name`, parsed at `:363`) — the agent name **is already available** to this script, it is
  simply not used to gate the handoff-expectation check.
- Its own design comment, "D1: dispatch-derived handoff expectation (no agent-name list)"
  (`:719-727`), states the policy explicitly: *"Writer expectation is derived from the DISPATCH,
  not from an agent-name allowlist. ... every caller of this script today is a `dispatch[]` row
  (never an `aux_dispatch[]` row) ... so every dispatch that reaches this script is, by
  construction, handoff-expected. ... There is no agent-name list to widen or fall behind the
  agent roster — this predicate is self-maintaining as agents and extensions are added."* This
  reasoning is sound for every other current writer but does not anticipate `resolve_agent()`'s
  artifact-based routing putting a non-writing agent into the same `dispatch[]` array.
  `--handoff-expected` (default `"true"`, parsed `:353/:371`) already exists as an opt-out knob for
  exactly this kind of exception, but Move 3's call site (`SKILL.md:213-218`) never passes it —
  there is currently no caller that ever sets it to `false`.
  **I verified this comment's framing is self-consistent, not merely a stale note**: the predicate
  really is phase-keyed, not agent-keyed, at the one place that matters (the severity-split
  `if [ "$phase" = "research" ]` at `:915`, discussed next), so the gap is exactly where the
  comment above implies it could appear — a `dispatch[]` row whose agent is not actually a writer.
- The severity-split check that actually fires the misleading `RECOVERY ... UNEXPECTED` message
  (`:906-918`) branches on `$phase` only: `research` -> `NOTE` (expected, no handoff ever), any
  other phase (`plan`, `implement`) -> `RECOVERY: ... UNEXPECTED: the ${phase} phase's writer is
  contractually required to write .orchestrator-handoff.json on every orchestrator_mode: true
  dispatch.` Its own code comment (`:906-914`) attributes this rule to "every `agents/*research*
  .md`'s own ... subsection, and every `agents/*implement*.md` / `planner-agent.md`'s own ...
  MUST-write subsection" — correctly citing `planner-agent.md` by name for the plan phase, but
  never anticipating that the `plan` phase's *agent* can also be `reviser-agent`.

**`docs/architecture/handoff-schema.md` — the authoritative contract text**

- Its "Handoff Writers — the settled decision, in one place" section (`:469` onward) states this
  is explicitly the single place to look: *"Core's own standalone hard-mode implementation agent
  ... is not a special case among writers — every implementation agent, plus `planner-agent`, is a
  writer under this one `orchestrator_mode` gate."*
- The writer table itself (`:491`) lists exactly one row for the non-implementation case: *"Every
  `*-implementation-agent`/`*-implement-agent` plus `planner-agent`, across every extension"* —
  `reviser-agent` is **not present** in this table at all, in either direction. The doc is not
  self-contradictory on its own terms (it simply never claims `reviser-agent` is a writer), but it
  is incomplete: it documents the Move-2-driven, phase-keyed expectation nowhere, and so gives a
  reader no way to resolve the discrepancy between "every `plan`-phase `dispatch[]` row is
  handoff-expected" (Move 2 + postflight's actual behavior) and "only `planner-agent` is a writer"
  (this table's actual content).
- "Registering a new writer" (`:531`) confirms the intended mechanism for closing this gap is
  exactly what Section Decisions below proposes: *"add a row to the Handoff Writers table above.
  No script-side [change needed]"* — i.e., the table is designed to be extended per-agent without
  touching `orchestrate-cycle-postflight.sh`.

**`agents/planner-agent.md` — the template to mirror**

- Its own `.orchestrator-handoff.json (orchestrator-mode dispatches)` section (`:501-531`) is the
  exact pattern: conditional on `orchestrator_mode: true` in the delegation context, writes to the
  `handoff_path` field (falling back to `{task_dir}/.orchestrator-handoff.json`), explicit
  `dispatch_seq` echo rule, references `context/schemas/orchestrator-handoff-schema.json` /
  `docs/architecture/handoff-schema.md` for shape, and states plainly: *"A delegation context that
  does NOT carry `orchestrator_mode: true` carries no handoff obligation; do not write the file in
  that case."* This conditional form is precisely what Call Path 1 (aux, `orchestrator_mode:
  false`) vs. Call Path 2 (dispatch, `orchestrator_mode: true`) already needs for `reviser-agent`.

### External Resources

Not applicable — this is a pure internal-contract/documentation defect confined to this
repository's orchestration engine; no external library or API is involved.

## Recommendations

**Chosen direction: (a) — make `reviser-agent` a conditional handoff writer, gated on
`orchestrator_mode`, exactly like `planner-agent`.** Do not pursue (b) (reclassifying the
dispatch). Rationale and blast radius for each, as the task's scope item 2 requires:

**(a) Make `reviser-agent` write a handoff on an `orchestrator_mode: true` dispatch — chosen**

Files touched, all under `agent-system/extensions/core/` (source store):
1. `agents/reviser-agent.md` — add a `.orchestrator-handoff.json (orchestrator-mode dispatches)`
   section mirroring `planner-agent.md:501-531` verbatim in structure: conditional on
   `orchestrator_mode: true`, write before returning on success/`partial`/`blocked` alike, use
   `handoff_path` with the `{task_dir}/.orchestrator-handoff.json` fallback, echo `dispatch_seq`
   unchanged, `status` one of `planned`/`partial`/`blocked` (reusing the Stage 6 vocabulary already
   in the file), `phases_total`/`phases_completed` populated the same way `planner-agent.md`
   populates them for a freshly (re-)written plan. Add the two new MUST-DO items to "Critical
   Requirements" (write the handoff when `orchestrator_mode: true`; do NOT write it otherwise —
   covering Call Path 1 explicitly so the aux path stays handoff-less by the same conditional, not
   by a second hardcoded rule).
2. `docs/architecture/handoff-schema.md` — add `reviser-agent` to the "Handoff Writers" table row
   (or a new row) alongside `planner-agent` for the plan phase, since "Registering a new writer"
   (`:531`) already documents this exact table-only extension mechanism with "No script-side
   [change needed]" — confirming this doc anticipated exactly this kind of addition.
3. `skills/skill-orchestrate/SKILL.md` — clarify row 383 of the Skill-to-Agent Mapping table (or
   add a note beneath it) stating that the "Plan" dispatch's resolved agent can be `planner-agent`
   OR `reviser-agent` depending on `orchestrate-cycle-plan.sh`'s artifact-based admission rule
   (Phase 5), and that in this `dispatch[]` path (unlike row 385's `aux_dispatch[]` path)
   `orchestrator_mode` is `true` for either resolved agent. This is the one line that was actually
   missing and caused the apparent contradiction with row 385.

No change needed to `orchestrate-cycle-plan.sh` (the artifact-based admission rule is intentional
and correctly test-pinned by Group 23 Cases C/E) or to `orchestrate-cycle-postflight.sh` (its
phase-keyed, dispatch-derived design is sound and self-maintaining once `reviser-agent` actually
writes the handoff it is now contractually asked for — no agent-name list needs to be introduced
into the script, consistent with its own D1 design comment at `:719-727`).

**(b) Stop classifying a forced-plan reviser row as a handoff-writing dispatch — rejected**

Files it would touch: `scripts/orchestrate-cycle-postflight.sh` (introduce an agent-name check —
e.g. `[ "$agent_name" = "reviser-agent" ]` — into the severity-split at `:915` and/or into the
`--handoff-expected` plumbing), `skills/skill-orchestrate/SKILL.md` Move 3's call site (`:213-218`,
to compute and pass `--handoff-expected false` when the row's `agent` is `reviser-agent`), and
likely `docs/architecture/handoff-schema.md` (to document the new exception). Rejected because:
- It requires introducing exactly the per-agent-name allowlist that `orchestrate-cycle-
  postflight.sh`'s own design comment (`:719-727`) explicitly rejected as a maintenance hazard
  ("no agent-name list to widen or fall behind the agent roster").
- It treats the dispatch mechanics (which are deliberate, documented, and test-pinned) as the
  thing to change, when the actual gap is narrower and cheaper: one agent file missing a
  conditional section every sibling writer already has.
- It would leave `reviser-agent` permanently unable to report `partial`/`blocked` outcomes back to
  the orchestrator via the handoff channel on a forced-plan dispatch, degrading observability for
  that path rather than improving it.

## Decisions

- Confirmed the task's root-cause hypothesis: `reviser-agent` is reachable by two call paths
  (`aux_dispatch[]` with `orchestrator_mode: false`/no `handoff_path`, and `dispatch[]` "plan"
  phase with `orchestrator_mode: true`/`handoff_path` supplied) and `agents/reviser-agent.md`
  documents a handoff contract for neither — it was simply never given one, on either path.
- Decided to pursue candidate fix (a): add a conditional, `orchestrator_mode`-gated
  `.orchestrator-handoff.json` section to `agents/reviser-agent.md`, mirroring
  `agents/planner-agent.md`'s existing section, rather than (b) reclassifying the dispatch.
- Decided the schema-doc fix belongs in `docs/architecture/handoff-schema.md`'s "Handoff Writers"
  table, per that doc's own documented "Registering a new writer" procedure (table-row addition
  only, no script change).
- Decided `skills/skill-orchestrate/SKILL.md`'s Skill-to-Agent Mapping table also needs a small
  clarifying addition (not a correction — its existing rows are each individually accurate for the
  path they describe) so a reader does not have to re-derive, from the script, that the "Plan"
  row's resolved agent can be `reviser-agent` under `orchestrator_mode: true`.
- Decided no change is needed to `orchestrate-cycle-plan.sh` or `orchestrate-cycle-postflight.sh`.

## Risks & Mitigations

- **Risk**: adding a handoff-writing section to `reviser-agent.md` could regress the Call-Path-1
  (aux, `orchestrator_mode: false`) behavior if the new section is written unconditionally instead
  of gated. **Mitigation**: mirror `planner-agent.md`'s section exactly, including its explicit
  "A delegation context that does NOT carry `orchestrator_mode: true` carries no handoff
  obligation; do not write the file in that case" sentence, and add a MUST-NOT item reinforcing it.
- **Risk**: `scripts/tests/test-orchestrate-cycle-plan.sh`'s Group 23 Cases C/E only assert the
  resolved `agent` field in the dispatch row; they do not exercise the agent's own behavior, so
  they will not catch a reviser-agent handoff regression — that needs a new or extended test (at
  the agent-contract or integration level) once this is implemented. Flagging for the planning
  phase rather than fixing here, since this report is research-only.
- **Risk**: `docs/architecture/handoff-schema.md`'s "Handoff Writers" table is described as *the*
  single source of truth read by multiple other narratives in the same file (e.g. the `partial`
  with-continuation and "One Write Form" sections); a future editor adding the `reviser-agent` row
  should re-grep the file for other places that enumerate the writer set by name (e.g. the
  `continuation_path` row at `:122`, which currently names only hard-mode implementation agents)
  to decide if any need the same addition. This report did not exhaustively diff every such
  mention; it anchors on the one table explicitly declared authoritative (`:469`, `:491`).

## Context Extension Recommendations

- **Topic**: `resolve_agent()`'s artifact-based plan-admission rule (Phase 5,
  `orchestrate-cycle-plan.sh:2115-2186`) and its interaction with the Handoff Writers contract.
- **Gap**: No context file currently documents, in one place, that the `plan` operation's resolved
  agent is chosen by artifact presence (not by task status or any flag) and that this choice feeds
  the *same* generic `dispatch[]`/handoff machinery as every other phase — a reader has to
  reconstruct this by cross-referencing the script, `SKILL.md`, and `handoff-schema.md`
  independently, as this research did.
- **Recommendation**: consider a short cross-reference note (in `docs/architecture/handoff-
  schema.md`'s "Handoff Writers" section, or a new short pattern file under
  `context/patterns/`) stating explicitly that a `dispatch[]` row's handoff-writer identity is
  determined by the *resolved agent*, not the *phase name* — generalizing the lesson from this
  task so a future phase whose agent resolution is also artifact-based (rather than purely
  task-type-routed) does not repeat this gap.

## Appendix

### Search queries / investigation steps used

- Resolved `source_dir` via `.claude-extensions.json` and located all relevant files under
  `agent-system/extensions/core/` directly (never read or edited anything under `.claude/`).
- `grep -n "reviser"` across `skills/skill-orchestrate/SKILL.md` and `orchestrate-cycle-plan.sh`.
- `grep -n "orchestrator_mode"` across `orchestrate-cycle-plan.sh` to enumerate every row-builder
  site and confirm both aux row-builders (`:1472`, `:1529`) hardcode `orchestrator_mode: false`.
- Full read of `agents/reviser-agent.md` (all stages, Critical Requirements) to confirm the
  absence of any `.orchestrator-handoff.json` section.
- Full read of `skills/skill-orchestrate/SKILL.md` Move 2 (dispatch/aux_dispatch loops, `:155-196`)
  and Move 3 (postflight call site, `:198-220`) to confirm the generic, agent-agnostic row
  templates and the `--agent` argument already being passed to postflight.
- Traced `resolve_agent()`'s two call sites (`:2370` dry-run, `:2732` live) to confirm both feed
  `out_dispatch_rows` (the `dispatch[]` array), never `aux_dispatch[]`.
- Read `orchestrate-cycle-postflight.sh`'s "D1" design comment (`:719-727`) and the severity-split
  check (`:906-918`) that produces the exact `RECOVERY ... UNEXPECTED` message quoted in the task
  description.
- Read `docs/architecture/handoff-schema.md`'s "Handoff Writers" section (`:469-531`) and
  `agents/planner-agent.md`'s `.orchestrator-handoff.json` section (`:501-531`) as the template for
  the recommended fix.
- Confirmed via `grep -n "reviser-agent"` in `scripts/tests/test-orchestrate-cycle-plan.sh` that the
  existing-plan -> `reviser-agent` dispatch-row resolution is intentional and test-pinned (Group
  23 Cases C and E, plus the separate aux-chaining assertions at `:1088`/`:1128`).
- Checked `specs/state.json` nearest-miss per the task's own rejection note; confirmed task 370 is
  unrelated (schema-reaches-agent concern, not a writer-omission concern) and no other filed task
  covers this defect.

### References

- `agent-system/extensions/core/agents/reviser-agent.md`
- `agent-system/extensions/core/agents/planner-agent.md`
- `agent-system/extensions/core/skills/skill-orchestrate/SKILL.md`
- `agent-system/extensions/core/scripts/orchestrate-cycle-plan.sh`
- `agent-system/extensions/core/scripts/orchestrate-cycle-postflight.sh`
- `agent-system/extensions/core/docs/architecture/handoff-schema.md`
- `agent-system/extensions/core/scripts/tests/test-orchestrate-cycle-plan.sh`
