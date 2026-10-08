# Research Report: Task #306

**Task**: 306 - Make ROADMAP.md a generated artifact: extend the format into a generation
contract and add regenerate and prune modes
**Started**: 2026-10-08T06:16:00Z
**Completed**: 2026-10-08T06:45:00Z
**Effort**: Medium (wiring + a contract rewrite; no new DAG/wave algorithm)
**Dependencies**: None (wave 1, per `specs/TODO.md`'s Dependency Waves table)
**Sources/Inputs**: Codebase (`agent-system/extensions/core/`), `specs/state.json`,
`specs/ROADMAP.md`, `specs/TODO.md`, git history of `specs/ROADMAP.md`
**Artifacts**: - this report
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- **The dispatch's premise about the live file's shape is stale.** `specs/ROADMAP.md` was
  rewritten (git `a59f8f373`, then again through `7a2b3bae1`) into a `## Open work` /
  `## Next` prose-and-fenced-block format that uses NEITHER the `## Phase N:` /
  checkbox/table shape `context/formats/roadmap-format.md` currently documents, NOR the
  literal `**Status**`/`**Milestones**`/`**Blocked by**`/`**Topics**`/`**Run**` bold field
  labels the dispatch names — those exact labels do not appear anywhere in the file's git
  history I could find. Ground the generation contract in the **measured current shape**,
  not in the dispatch's field-name list, which is best read as a conceptual summary (status,
  blocking, topic grouping, copy-pasteable runs), not a literal spec.
- **`scripts/roadmap-integration.sh` is dead code, quarantined in `scripts/deprecated/`, not a
  live script with "only parse-only and --annotate" to extend.** It was retired precisely
  because its `## Phase N:`/checkbox/table parser cannot parse the current file at all
  (`phases=0, checkboxes=0, table_rows=0, parseable=false` on every invocation) and because its
  in-place annotation model conflicts with the roadmap's own "finished work is removed, not
  archived here" policy. Its CLI scaffold (arg parsing, stderr marker convention) is salvageable
  prose/pattern; its substantive parse/annotate logic is not, and must not be "extended" — it
  must be replaced.
- **The genuinely reusable machinery is `generate-task-order.sh --print`'s Dependency Waves
  table and topic grouping** (`compute_waves`/`generate_wave_table`, lines 393/708) plus
  `read_existing_goal`'s authored-prose-retention pattern (line 905) — exactly as the dispatch
  directs, and verified present and callable as a read-only subprocess.
- **No existing or near-term script can derive the `## Next` section's Run-block batch
  groupings.** `MAX_TASKS=8` truncation in `commands/orchestrate.md` is the only mechanical
  batching that exists; the "next admissible batch" suggestion engine is task **274**'s
  not-yet-built scope, and 306 has no dependency edge to it. Recommend: generate Run blocks as a
  naive per-wave chunk (ceil to 8), and keep the "why this order" prioritization prose authored.
- **Three live roadmap "Unfiled observations" explicitly say "belongs with 306"**, but all three
  name fix sites inside concurrent siblings' file_scope (271's `generate-task-order.sh`/
  `generate-todo.sh`, 272's `orchestrate-predispatch-review.sh`) — not inside 306's own
  file_scope. Flag these as out-of-scope cross-references for 306's plan, not defects 306 should
  fix directly.
- **Per-task "ready"/"blocked:N,M"/HOLD status is simple to derive and does not require the wave
  algorithm**: it is a one-pass filter of `dependencies[]` against the active (non-terminal) task
  set, byte-identical in spirit to `get_active_tasks()`'s one-line jq query already used inside
  `generate-task-order.sh`. `HOLD` is fully schema-supported (`hold_reason`/`held_at`); the
  dispatch's "hold was unsupported" claim is independently confirmed false. `EXT-BLOCKED` has
  **no schema support at all** — it is prose-only today — and needs a design decision (see
  Decisions).

## Context & Scope

Researched what the current codebase actually contains for ROADMAP.md generation, against the
dispatch's three SCOPE items: (1) extend `context/formats/roadmap-format.md` into a generation
contract, (2) add regenerate/prune modes to `scripts/roadmap-integration.sh`, (3) specify what is
authored vs. generated. The dispatch's own REUSE directive named four things to check before
writing anything new: `compute_waves`/`generate_wave_table` in `generate-task-order.sh`,
`read_existing_goal`, `generate-task-order.sh --print`'s read-only output, and
`orchestrate-cycle-plan.sh`/`orchestrate-batch-admit.sh` for duplication. All four were read.
Constraint honored throughout: `generate-task-order.sh` must not be modified (task 271's
file_scope); 306 must only consume its output.

## Findings

### Codebase Patterns

**1. `specs/ROADMAP.md`'s actual live shape (measured 2026-10-08), not the dispatch's assumed
shape.**

```
# Roadmap
## Goal                 <- intro prose; explicitly says "it is hand-derived until 306 makes it generated"
## Gate state            <- measured, dated bullets (verify-deploy state, budget headroom, etc.)
## Next                  <- fenced /orchestrate Run blocks (one line per batch) + "Why this order" prose
## Open work             <- per-CATEGORY fenced blocks: "**{Category} (count)**" header, then
                            one line per task: "{N} {status-token}  {description}  [<- priority]"
                            where status-token in {ready, blocked:N[,M...], HOLD, EXT-BLOCKED, IN FLIGHT}
## Checks before and after every call
## Settled decisions (do not re-litigate)
## Standing rules
## Unfiled observations (none worth a task yet)
```

There is **no wave table**, **no `## Phase N:` heading**, **no checkbox**, **no status table**,
and **no literal `**Status**`/`**Milestones**`/`**Blocked by**`/`**Topics**`/`**Run**` bold
field** anywhere in this file or in any commit of it I inspected back through
`617a03b54`/`ed41e1d48`/`a59f8f373` (three successive full rewrites, each with a different ad hoc
shape — per-call markdown tables, then `## Call N` headers, then the current `## Open work`
category blocks). `context/formats/roadmap-format.md`'s existing 65-line spec (Phase headers,
checkboxes, status tables, completion annotation) matches **none** of these three historical
shapes either — it describes a fourth, even older shape that predates all of them. The format has
never been stable; that instability is the whole motivation for this task, and the new contract
must be written against the *current* measured shape, re-verified at implementation time (per
Standing rule 5: "re-measure before acting on it").

**2. `scripts/roadmap-integration.sh` is dead, not a live script with two modes to extend.**

`find agent-system -iname "roadmap*"` shows it at
`agent-system/extensions/core/scripts/deprecated/roadmap-integration.sh`, not at
`agent-system/extensions/core/scripts/roadmap-integration.sh` (the path in 306's own
`file_scope` and in the dispatch's SCOPE item 2). `scripts/deprecated/README.md`'s own entry for
it states the retirement reason precisely: `specs/ROADMAP.md` was rewritten into hand-curated
`## Stage N: ...` prose (an intermediate shape, since further rewritten again) that the script's
`## Phase N:`/checkbox/table parser cannot match, so every invocation reported
`phases=0, checkboxes=0, table_rows=0, parseable=false` — a complete, silent, permanent capability
loss, not a partial one. The same README entry names a second, independent conflict: the script's
in-place `*(Completed: Task N, DATE)*` annotation model contradicts the roadmap's own stated
policy ("Finished work is removed, not archived here"). Reading the script directly
(`cat -n`) confirms its substantive logic is a `python3` heredoc built entirely around
`## Phase N:` regex matching, checkbox toggling, and table-row annotation — none of it
transfers to the current `## Open work`/`## Next` shape. Its CLI arg-parsing scaffold
(`--roadmap`/`--state`/`--annotate`/`--dry-run`) and its "always-present machine-readable stderr
marker" convention are reusable *patterns*, but the parse/cross-reference/annotate body is not
salvageable without a full rewrite. Two dedicated test suites for it
(`tests/test-roadmap-argv-ceiling.sh`, `tests/test-roadmap-items-producer.sh`) are also quarantined
alongside it, confirming zero live callers anywhere in `agent-system/extensions/**`.

**Practical implication for SCOPE item 2**: "add two modes to a script that today has only
parse-only and --annotate" is accurate as a description of the file's current CLI surface, but
that surface currently does nothing useful against the live roadmap. The plan phase should treat
this as: move the file out of `scripts/deprecated/` back to `scripts/roadmap-integration.sh` (or
accept the dispatch's existing `file_scope` naming it there already), and **replace** its
parse/annotate internals to consume `generate-task-order.sh --print` and `state.json` directly,
rather than attempting to patch its old `## Phase N:` regex engine.

**3. The reusable wave/topic machinery is exactly where the dispatch said, and works today.**

```
generate-task-order.sh:149   get_active_tasks()      -- one-line jq: active, non-terminal tasks, status, deps
generate-task-order.sh:184   build_graph()            -- loads task_desc, task_status, task_deps (CLEANED:
                                                          only deps that are themselves still active/non-terminal)
generate-task-order.sh:303   transitive_reduce()      -- removes redundant edges from task_deps
generate-task-order.sh:360   load_topics()
generate-task-order.sh:393   compute_waves()          -- Kahn's algorithm -> wave_assignment[task]=N
generate-task-order.sh:708   generate_wave_table()    -- "| Wave | Tasks | Blocked by | Topics |" markdown
generate-task-order.sh:905   read_existing_goal()     -- preserves authored **Goal** line across regen
```

Verified: `generate-task-order.sh --print` is a top-level script (no function-sourcing boundary —
`set -euo pipefail` plus unconditional `build_graph`/`compute_waves`/... calls at file-scope, lines
1012-1044) so it **cannot be `source`d** to call `compute_waves` directly; it must be invoked as a
subprocess and its stdout parsed/extracted, exactly as the dispatch directs ("roadmap-integration.sh
must CONSUME that output"). `specs/TODO.md`'s current `## Task Order` section (lines 7-18) shows
this machinery's live output: a 5-wave Dependency Waves table plus a topic-grouped indented tree —
confirming the dispatch's MOTIVATION claim that this table already reproduces, mechanically, the
same wave/blocked-by/topics information the hand-written roadmap re-derives by hand.

However: **the current `## Open work` section's per-task `ready`/`blocked:N,M`/`HOLD` lines are
NOT the wave table and are not produced by any existing generator.** They are a different,
finer-grained rendering (per-task, not per-wave) that happens to be derivable from the *same*
underlying `task_deps`/`task_status` data `build_graph()` already computes internally, but that
data is not exposed in `--print`'s output format (which only emits the aggregated wave table and
the DFS topic tree, never a flat per-task ready/blocked-by line). Re-deriving per-task
ready/blocked-by status needs only a one-pass filter — `dependencies[] ∩ active-task-set` is empty
-> "ready", else -> "blocked:" + sorted comma list — which is the same one-jq-line shape as
`get_active_tasks()` itself (not a new DAG/wave implementation, so writing it directly in the new
roadmap-integration.sh does not violate the "do not rebuild wave/DAG logic" instruction).

**4. `orchestrate-cycle-plan.sh`/`orchestrate-batch-admit.sh` do not duplicate anything 306
needs, and no batch-suggestion engine exists yet.**

`orchestrate-batch-admit.sh` is a cross-batch `file_scope` collision/admission predicate for a
*given* candidate set at dispatch time — it answers "can these tasks run together right now,"
not "which tasks should be proposed as the next batch." `commands/orchestrate.md`'s only batching
mechanism is a hard `MAX_TASKS=8` truncation (`validated_tasks[@]:0:$MAX_TASKS}`) with a warning —
no priority-aware chunking. The live `## Next` section's Run blocks (e.g.
`/orchestrate 271, 306, 273`) are entirely hand-curated judgment calls, confirmed directly by
`specs/ROADMAP.md`'s own `## Open work` entry: **`274 blocked:272,273,275,344
next-admissible-batch suggestion and alternatives-on-conflict`** — this capability is explicitly a
different, not-yet-built, future task, and 306 carries no dependency edge to it (306 has zero
dependencies; nothing blocks it on 274, but nothing from 274 is available to 306 either).

**5. HOLD is schema-supported; EXT-BLOCKED is not.**

`validate-state.sh` line 506 lists `hold_reason held_at prior_status research_questions` as known
schema fields, and lines 925-931 implement a terminal-status-immutability check keyed on
`prior_status`. Verified live example: task 342's state.json entry carries `status: "hold"`,
`hold_reason` (full prose), `held_at: "2026-10-05"`, `prior_status: "not_started"`. This
independently confirms the dispatch's MOTIVATION claim that `roadmap-format.md`'s stale claim
("`hold` is unsupported and breaks generate-todo.sh/validate-state.sh") was false. By contrast,
`EXT-BLOCKED` (task 349: "/approve as one interactive question... (also EXT-BLOCKED)") has **no
corresponding state.json field** — task 349's `dependencies` is `[300]` (an in-repo, already-
resolved task number), so the external-repo blocker is carried **only as roadmap prose**, invisible
to `state.json`/`validate-state.sh`/`orchestrate-predispatch-review.sh` entirely. This is also
independently confirmed by the roadmap's own "Unfiled observations": *"Nothing represents a
cross-repository prerequisite. A task gated on another repo reads `ready` here and can only be
caught by reading its description. 349/350 are the live instance."*

**6. The "Phase 0 of user-only owner decisions" the dispatch asks about has already been resolved
informally in the current file, by annotation rather than by segregation.** Task 342's hold entry
in the current `## Open work` section is immediately followed by a dedicated prose paragraph
(*"342's hold: every dependency is satisfied. The hold stands on the version stamp alone... Lift
when that line reads 0.1.0 — owner action, never an agent's."*) rather than a separate "Phase 0"
section. This matches `hold_reason`'s existing free-text field exactly — the owner-gated condition
already lives in `hold_reason`, and the roadmap's prose paragraph is effectively a rendering of
that same field. No separate "owner decisions" section exists in the current (or any of the three
prior rewritten) roadmap shapes I inspected.

**7. Three "belongs with 306" observations in the live roadmap name fix sites outside 306's
file_scope, colliding with concurrent siblings 271 and 272.**

`specs/ROADMAP.md`'s `## Unfiled observations` section contains, verbatim:

- *"Four open tasks carry no `title` key (328, 338, 349, 350)... `orchestrate-predispatch-review.sh`
  Class B checks only for a literal null and misses an absent key. Belongs with **306**."*
  — Verified: `jq '.active_projects[] | select(.project_number==N) | has("title")'` returns
  `false` for all four. The fix site named (`orchestrate-predispatch-review.sh`) is in task
  **272**'s declared file_scope (this dispatch's own Territory block, concurrent sibling), not
  306's.
- *"`TODO.md`'s tree view strips punctuation from titles, rendering a backticked identifier as
  `SKILLVALIDATEFIXES`... Cosmetic; belongs with **306**."* — The rendering logic is
  `generate-task-order.sh`'s `desc_data` jq pipeline (gsub chain, line ~210). That file is in task
  **271**'s declared file_scope (concurrent sibling), explicitly named in the dispatch as off
  limits ("do NOT modify generate-task-order.sh").
- *"A rendered `**Goal**:` line in `TODO.md` cannot survive regeneration... `generate-task-order.sh
  --goal` writes it; `generate-todo.sh` drops it and never reads `active_goal`... Belongs with
  **306**."* — Same file (`generate-task-order.sh`) plus `generate-todo.sh`, both in task 271's
  file_scope.

None of these three fix sites is reachable by 306 without a direct file_scope collision against a
task dispatched concurrently in this same cycle (per the dispatch's own Territory block, which
lists 271 and 272 as `concurrent_siblings`). Research recommends treating all three as
**cross-references for 271/272's own backlog, not line items in 306's plan** — see Decisions.

### External Resources

No external (web) research was needed or performed; this is a pure in-repo wiring task and the
dispatch explicitly directs against inventing new machinery. All findings above are grounded in
the live codebase and git history.

## Recommendations

1. **Rewrite `context/formats/roadmap-format.md` against the measured current shape** (Goal /
   Gate state / Next / Open work / Checks / Settled decisions / Standing rules / Unfiled
   observations), not against the dispatch's literal field-name list and not against the
   existing 65-line Phase/checkbox/table spec (which matches none of the last three rewrites).
   Model it on `context/formats/task-order-format.md`'s structure (placement, section headers,
   explicit regexes, a clear authored-vs-generated split) — that file is the house's existing
   exemplar for a *generation contract*, as opposed to roadmap-format.md's current *parse
   spec for a human-maintained file*.
2. **Specify the authored/generated split explicitly, per section**, something like:
   - Generated, every regenerate: `## Open work` (per-task status/blocked-by/topic lines,
     derived from `state.json` + the wave/topic data), the Run-block skeleton under `## Next`
     (task membership, chunked by wave and `MAX_TASKS=8`).
   - Authored, retained across regenerate (via a `read_existing_goal`-style lookup keyed by
     batch/phase identity, not touched unless the author edits it): the "why this order"
     prose under `## Next`, the one-line-per-category and one-line-per-batch descriptions,
     `## Settled decisions`, `## Standing rules`, `## Unfiled observations`.
   - Measured-not-generated (left to `/review`'s or an operator's hand, out of scope for a
     mechanical regenerate): `## Gate state`'s dated, measured bullets (verify-deploy figures,
     budget headroom) — these require running checks, not reading state.json.
3. **Build the new `roadmap-integration.sh` (currently quarantined) as a consumer of
   `generate-task-order.sh --print`'s stdout plus a direct, small jq pass over `state.json`** for
   per-task ready/blocked-by/HOLD status (the one-pass filter in Finding 3) — not by patching the
   deprecated script's `## Phase N:` parser, and not by reimplementing Kahn's algorithm.
4. **`EXT-BLOCKED` needs a design decision before implementation**: either (a) add a lightweight,
   additive state.json field (e.g. `external_blocker: true` / a free-text note) — but this touches
   `state-schema.json`, in task 271's file_scope, creating the same cross-task collision risk as
   Finding 7 — or (b) keep it prose-only, preserved across regeneration the same way authored
   per-task descriptions are (an authored annotation keyed by task number, not a schema change).
   Recommend (b) for 306 specifically, to stay clear of 271's territory; flag (a) as a longer-term
   follow-up for 271 or a new task.
5. **Do not attempt the three "belongs with 306" observations (Finding 7) inside this task.** File
   them (or let the plan note them) as out-of-scope cross-references pointing at 271 and 272's own
   backlogs instead.
6. **Regenerate mode**: full rebuild of `## Open work` + `## Next`'s task-membership skeleton from
   `state.json` (consuming `generate-task-order.sh --print` for wave/topic grouping plus the new
   direct per-task status derivation), preserving every authored field named in Recommendation 2.
   **Prune mode**: narrower — drop completed/abandoned/expanded tasks from `## Open work`, and
   remove a whole batch/phase entry under `## Next` once every task it names is terminal, without
   touching any other authored prose. This split matches the dispatch's stated
   "`/todo` prunes; `/review` regenerates completely" responsibility division, even though the
   two concrete consumer tasks (307, 308) that were meant to wire these modes into `/todo`/`/review`
   were abandoned into task 328 on 2026-10-03 (git `a59f8f373`) — see Decisions.

## Decisions

- **Ground roadmap-format.md's contract in the measured 2026-10-08 file shape, not in the
  dispatch's named field list.** The dispatch's "Status/Milestones/Blocked by/Topics/Run" list
  does not match any historical version of the file (three rewrites inspected); treat it as
  conceptual intent (what information the file conveys), not a literal spec to transcribe.
- **`scripts/roadmap-integration.sh` must be substantially rewritten, not incrementally extended.**
  Its existing parse/annotate body targets an incompatible, long-superseded format and is
  explicitly flagged by `scripts/deprecated/README.md` as not restorable by adding a caller alone.
- **The dependent-task responsibility split named in the dispatch ("implemented by the two
  dependent tasks: /todo prunes; /review regenerates completely") refers to tasks 307 and 308,
  which no longer exist as standalone tasks** — both were abandoned and folded into task 328
  ("systematic script and test corpus efficiency") on 2026-10-03 (git `a59f8f373`). Task 328's own
  description still names the `/todo`-roadmap-pruning and `/review`-roadmap-regeneration substance
  verbatim under its "FOLDED-IN TASKS" section, so the *intent* survives, but **328 has no
  dependency edge on 306** in current state.json (`dependencies: [170, 303, 304, 318, 322, 366]`),
  even though 328's folded-in roadmap-wiring substance logically needs whatever regenerate/prune
  interface 306 builds. This is a real sequencing gap the plan or a follow-up note should record
  (e.g., flag that 328's roadmap-wiring sub-scope should not be started before 306's
  regenerate/prune modes exist, even without a formal edge) — out of scope for 306 to fix itself
  (editing 328's dependency list is not inherently 306's file_scope either, but noting the gap in
  the plan's artifact is appropriate).
- **Per-task ready/blocked-by derivation is a simple filter, not a wave/DAG computation**, and can
  be written directly in the new roadmap-integration.sh without violating the "do not rebuild"
  directive, since it mirrors `get_active_tasks()`'s existing one-line jq shape rather than
  reimplementing `compute_waves`.
- **No mechanical "next admissible batch" capability exists or is reachable from 306**; Run-block
  generation should use naive per-wave `MAX_TASKS=8` chunking, leaving prioritization prose
  authored.

## Risks & Mitigations

- **Risk**: Implementing against the dispatch's literal field names instead of the measured shape
  produces a contract that doesn't match the live file at all. **Mitigation**: this report
  documents the measured shape in full (Finding 1); the plan should cite it directly.
- **Risk**: Reusing/reactivating `scripts/deprecated/roadmap-integration.sh` by patching its
  existing parser instead of replacing it, producing a script that still can't parse the current
  file. **Mitigation**: Finding 2 and Recommendation 3 are explicit that the parse/annotate body
  must be replaced, not patched.
- **Risk**: Scope creep into the three "belongs with 306" roadmap observations, causing a
  file_scope collision with concurrent siblings 271/272 dispatched this same cycle.
  **Mitigation**: Recommendation 5; Finding 7 documents the exact collision for each.
- **Risk**: `EXT-BLOCKED`/cross-repo-blocker representation scope-creeps into `state-schema.json`
  (271's territory). **Mitigation**: Recommendation 4 picks the prose-only option for 306.
- **Risk**: Attempting to mechanically reproduce the current hand-curated `## Next` batch
  groupings and "why this order" narrative in full, which is not mechanically derivable today.
  **Mitigation**: Recommendation 6/Decision note the naive-chunking fallback and keep the
  narrative authored.

## Context Extension Recommendations

- **Topic**: ROADMAP.md generation contract.
  **Gap**: `context/formats/roadmap-format.md` (65 lines, parse-spec-only) has no generation-
  contract sibling the way `context/formats/task-order-format.md` does for TODO.md's Task Order
  section.
  **Recommendation**: implement this task's rewrite of roadmap-format.md explicitly modeled on
  task-order-format.md's structure (placement, section headers + regexes, explicit
  authored-vs-generated split), so the two generated-artifact format docs stay structurally
  parallel for future maintainers.
- **Topic**: Cross-repository blocker representation.
  **Gap**: nothing in `state-schema.json`/`validate-state.sh`/`orchestrate-predispatch-review.sh`
  can represent "blocked by a prerequisite in another repository" (confirmed twice: Finding 5 and
  the roadmap's own Unfiled observations). This is a real, recurring gap (two live instances: 349,
  350) with no owner.
  **Recommendation**: file as a follow-up task once 306 settles whether EXT-BLOCKED stays
  prose-only or gets schema support (Decisions/Recommendation 4) — not 306's to resolve now.

## Appendix

### Search queries / commands used

- `jq '.active_projects[] | select(.project_number==N)' specs/state.json` (tasks 306, 328, 342,
  349, 365, and the four title-less tasks)
- `grep -rln "roadmap-integration.sh"`, `grep -rln "roadmap-format.md\|roadmap-update.md"` across
  `agent-system/`
- `git log --oneline --follow -- specs/ROADMAP.md`; `git show <rev>:specs/ROADMAP.md` at
  `a59f8f373`, `617a03b54` to compare historical shapes
- Direct reads: `generate-task-order.sh` (lines 1-130, 149, 184-360, 700-800, 1000-1053),
  `scripts/deprecated/roadmap-integration.sh` (header + grep for function/mode markers),
  `scripts/deprecated/README.md`, `context/formats/roadmap-format.md`,
  `context/patterns/roadmap-update.md`, `context/formats/task-order-format.md`,
  `commands/review.md` (`## Roadmap Progress` section), `skills/skill-todo/SKILL.md` (retired
  stage-id comment), `commands/orchestrate.md` (`MAX_TASKS` guard), `validate-state.sh` (line 506,
  925-931), `orchestrate-batch-admit.sh` (header)

### References

- `agent-system/extensions/core/context/formats/roadmap-format.md`
- `agent-system/extensions/core/context/patterns/roadmap-update.md`
- `agent-system/extensions/core/context/formats/task-order-format.md`
- `agent-system/extensions/core/scripts/generate-task-order.sh`
- `agent-system/extensions/core/scripts/deprecated/roadmap-integration.sh`
- `agent-system/extensions/core/scripts/deprecated/README.md`
- `specs/ROADMAP.md`, `specs/TODO.md`, `specs/state.json`
