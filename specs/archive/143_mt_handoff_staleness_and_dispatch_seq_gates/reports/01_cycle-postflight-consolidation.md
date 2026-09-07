# Research Report: Task #143

**Task**: 143 - Build `orchestrate-cycle-postflight.sh` (handoff staleness + dispatch_seq gates, widened)
**Started**: 2026-09-03T17:00:00Z
**Completed**: 2026-09-03T17:35:00Z
**Effort**: large (new ~10-concern consolidation script; one of the two remaining scripted moves in specs/PATH.md's Stage A)
**Dependencies**: 147 (`orchestrate-cycle-plan.sh`, satisfied and archived)
**Sources/Inputs**: codebase (SKILL.md Stage 5 / MT-4 / MT-5, orchestrate-stage5-gates.sh, orchestrate-stage5-postflight.sh, orchestrate-recover-outcome.sh, orchestrate-cycle-plan.sh, skill-base.sh), specs/PATH.md, specs/archive/state.json (tasks 53, 100, 138), context/standards/user-decision-contract.md, docs/architecture/handoff-schema.md
**Artifacts**: this report
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- The dispatch already fully specifies the target: **one new script**,
  `agent-system/extensions/core/scripts/orchestrate-cycle-postflight.sh`, callable as
  `orchestrate-cycle-postflight.sh <task_number> --session SID --state-file F`, returning one
  compact JSON line `{task, phase, status, phases_completed, phases_total, verdict, user_decision?, note}`.
  It is the third of three cycle scripts in specs/PATH.md's Stage A (after 146's
  `orchestrate-build-dispatch.sh` and 147's `orchestrate-cycle-plan.sh`), eventually called from
  both the still-live two-engine SKILL.md today and the single four-move loop after 88 rewrites it.
- Three existing scripts already implement ~70% of the needed logic in separated, single-task-only
  form: `orchestrate-stage5-gates.sh` (staleness/seq gate consumption, stray sweep, return-meta
  recovery, evidence corroboration, infra-failure discrimination, phase-marker recovery grep),
  `orchestrate-stage5-postflight.sh` (status-transition case ladder, completion-claim gate,
  artifact linking, artifact-round advance), and `orchestrate-recover-outcome.sh` (the
  `.return-meta.json` fallback reader). The new script's job is to (a) port the two gates
  currently missing entirely from Stage MT-4, (b) merge these three scripts' logic into one
  callable per task, (c) add three genuinely new behaviors — dispatch-identity-aware
  `HANDOFF_STALE_OR_ABSENT` suppression, `user_decision` relay, and a `modified_files`-vs-
  `file_scope` excursion advisory — and (d) add a scoped commit + multi-state update + lock
  release tail that today lives inline in SKILL.md's Stage MT-4 steps 5.5/6 (no single-task
  equivalent exists to reuse, since single-task mode's commit is currently a batch-style call
  elsewhere).
- **The two originally-named gates are fully specified already** — single-task Stage 5
  (`agent-system/extensions/core/skills/skill-orchestrate/SKILL.md:1749-1828`) is the exact
  mtime + `dispatch_seq` gate pair to port; Stage MT-4 step 1
  (`skill-orchestrate/SKILL.md:2808-2827`) is confirmed, by direct reading, to have **neither
  gate** — it reads the handoff whenever the file exists and only attempts recovery when the file
  is absent, exactly as the dispatch's DEFECT section states.
- **The two live incidents named in the description are fully documented** in
  `specs/archive/state.json`'s abandoned tasks 53 and 100 (see "Incident Detail" below) and give
  concrete fixture shapes for acceptance tests (4) and (1)/(2)/(3).
- One design question is NOT yet settled by any existing artifact and needs an explicit decision
  in the plan: how the new script determines, **per dispatch identity** (not per phase alone),
  whether the dispatched writer was a contractual writer for that specific dispatch — see "Open
  Design Question" below. Getting this wrong either re-introduces the spurious-defect bug (task 53)
  or silently swallows the genuine-clobber case (the two evt_ incidents).

## Context & Scope

Task 143 began as a narrow port (two gates, MT-4 only) and was revised in place to the seed of a
much larger consolidation: **`scripts/orchestrate-cycle-postflight.sh`**, the third and last
missing piece of specs/PATH.md's "four moves per cycle" design (Stage A.4). It absorbs three
sibling tasks that were abandoned with a pointer to this one:

| Absorbed task | Gap | Where it lands in the new script |
|---|---|---|
| 53 (`fix_spurious_handoff_stale_defect`) | Recording order: a contractual non-writer's expected empty handoff still records `HANDOFF_STALE_OR_ABSENT` | WORK item (d) — writer-contract-aware recording, keyed on dispatch identity |
| 100 (`aggregator file_scope excursion`) | `modified_files` vs declared `file_scope` is never compared | WORK item (h) — advisory-only excursion detection |
| 138 (gap 2 only; gaps 1 and 3 went to 147 and 146 respectively, both already landed) | Multi-task mode has no `next_artifact_number` advance mechanism | WORK item (g) — artifact-round advance on research and on a forced plan/implement |

The dispatch file (`.dispatch/1.md`) is authoritative for scope; this report does not restate its
eleven WORK items (a)-(j) but maps each to existing code, precedent, or an open question below.

## Findings

### Codebase Patterns

**Precedent scripts (already dedupe single-task base/hard mode; do NOT yet touch MT-4/MT-5):**

- `agent-system/extensions/core/scripts/orchestrate-stage5-gates.sh` (304 lines) — stray-handoff
  sweep (checks two exact paths, moves aside) + `.return-meta.json` recovery orchestration
  (delegates to `orchestrate-recover-outcome.sh`, then runs evidence corroboration via
  `skill_corroborate_phase_counts` on `PHASES_ZERO_ON_SUCCESS`, records
  `ARTIFACTS_SHAPE_MISMATCH`, and on a non-recovered outcome runs infra-failure discrimination and
  the sanctioned phase-marker recovery grep). Called from single-task Stage 5
  (SKILL.md:1842-1847) with 12-13 positional args; prints one JSON object, performs writes
  directly (system-defect-record.sh, loop-guard mutation) but never decides loop-control state.
- `agent-system/extensions/core/scripts/orchestrate-stage5-postflight.sh` (300 lines) — the
  `researched|planned|implemented|partial|failed|blocked|*` case ladder,
  `skill_gate_completion_claim` completion-claim gate, `skill_orchestrate_propagate_completion`
  call, artifact linking via `skill_link_artifacts`, and the artifact-round advance (fires
  unconditionally on `researched`, or on a FORCED `planned`/`implemented`). Called from Stage 5's
  "Shared postflight tail" (SKILL.md:2058-2066) with 19-20 positional args.
- `agent-system/extensions/core/scripts/orchestrate-recover-outcome.sh` (241 lines, strictly
  read-only) — the sole reader of `.return-meta.json` for outcome recovery. Its own header
  explicitly names the Item C decision (no fallback shape beyond `.metadata.*`/
  `.partial_progress.*`) and documents `evidence_suspect`/`evidence_reason`
  (`PHASES_ZERO_ON_SUCCESS`, `ARTIFACTS_SHAPE_MISMATCH`). **It has no `dispatch_seq` parameter or
  comparison today** — WORK item (b) requires adding one, mirroring the mtime-window parameter it
  already takes (`<task_dir> <window_start_ts>`), most likely as a new optional third
  `<expected_dispatch_seq>` argument that, when the recovered `.return-meta.json` (or a future
  schema field on it) does not itself carry a `dispatch_seq` to compare, must degrade gracefully —
  `.return-meta.json` today has **no `dispatch_seq` field at all** (confirmed by
  `context/formats/return-metadata-file.md`); this is a genuine schema gap, not a wiring gap (see
  Risks below).
- `agent-system/extensions/core/scripts/orchestrate-cycle-plan.sh` (991 lines, landed as 147) —
  the sibling "pre-dispatch" script this task's postflight companion must match in convention.
  Its header explicitly states: *"Everything from 'After all Agent tool calls complete' onward
  (per-task postflight, commits, the handoff/`.return-meta.json` read, and
  `cycle_modified_files` accumulation) is NOT this script's job — that is a separate, not-yet-built
  postflight composer."* This is the strongest confirmation that 143's widened scope is exactly
  147's declared complement, not scope creep. Its CLI convention
  (`--session SID --state-file F [flags...] <task_number> [<task_number>...]`, a `while [ "$#" -gt
  0 ]` case-based parser, `usage()` heredoc, `--help`) is the pattern the new script should copy
  verbatim for `--session`/`--state-file`. It also documents the exact field list the
  multi-task-state file (or, by the same convention, a single-task loop-guard-equivalent) carries:
  `dispatch_start_ts`, `dispatch_seq`, `dispatch_seq_counter`, `task_dirs`, `infra_failures`,
  `current_statuses`, `detected_defects`, etc. — all keyed by task number where the file is shared
  across tasks. The new postflight script will read several of these (`dispatch_start_ts[t]`,
  `dispatch_seq[t]`) exactly as Stage MT-4 step 1 already does inline (SKILL.md:2819,2751).

**Single-task Stage 5 gate pair to port (SKILL.md:1749-1828, both MUST move into the new
script/MT-4 verbatim in spirit):**

1. **Staleness gate** (mtime): `handoff_stale=false`; if the handoff file exists, compare its
   mtime against `dispatch_start_ts` (fail-closed default `9999999999` when unset); older →
   `handoff_stale=true`, record `HANDOFF_STALE_OR_ABSENT` via `system-defect-record.sh` +
   `skill_orchestrate_append_detected_defect`.
2. **`dispatch_seq` identity gate** ("Defect A", between the `dispatch-seq-gate:begin`/`:end`
   sentinels — a locked region per `specs/055_dedupe_orchestrate_skill_bodies/locked-regions.md`,
   referenced but not itself in this task's file_scope): only runs if the handoff exists and is
   not already stale; reads `.dispatch_seq` off the handoff; empty → WARN and degrade to
   mtime-only; mismatch against the cycle's minted `dispatch_seq` → sets `handoff_stale=true` and
   records the SAME `HANDOFF_STALE_OR_ABSENT` defect class (not a separate class) with a
   `dispatch-seq-mismatch`-suffixed detecting site.

Stage MT-4 step 1 (SKILL.md:2808-2827), read directly, confirms the DEFECT section's claim
exactly: it reads `task_dir/.orchestrator-handoff.json` "if present, continue to step 2" with **no
staleness or identity check at all** — the file's mere existence is trusted. Recovery is only
attempted when the file is *absent*, not when it is present-but-stale-or-mismatched. This is the
literal bug the OBSERVED section reproduces (a task directory holding an interrupted session's
`dispatch_seq=4` handoff against the cycle's minted `1`, reporting `phases_completed=0` while the
real dispatch had completed 6/6).

### Incident Detail (fixture material for ACCEPTANCE (1)-(4))

Both live incidents referenced by WORK item (d) are recorded in full in `specs/archive/state.json`
under the abandoned task 53 (`fix_spurious_handoff_stale_defect`), which this task absorbs:

- **`evt_1787614360544_SgKpRP`** (2026-08-24, separate lean4 consumer repo): a hard-mode implement
  dispatch minted `dispatch_seq=19`, went quiet ~25 min after writing its wrap-up summary, was
  judged terminated, and re-dispatched as a resume with `dispatch_seq=22`. The **original**
  dispatch was still alive, completed, and wrote a handoff (`status=implemented`, `5/5` phases)
  whose **mtime was newer than the resume's own window start** — the mtime gate alone would have
  passed it. Only the `dispatch_seq` comparison (`19` vs minted `22`) caught it.
- **`evt_1788246742189_Fodegl`** (2026-09-01, separate consumer repo, hard-mode): Phase 1's
  implementation agent finished cleanly with `dispatch_seq=3`; the orchestrator consumed and
  **deleted** both `.orchestrator-handoff.json` and `.return-meta.json`, then dispatched Phase 2
  with `dispatch_seq=4`. The Phase 1 agent then woke up (re-prompted about an unrelated question)
  and **restored both deleted files from its own prior git commit**, with a fresh mtime that fell
  **inside** Phase 2's dispatch window. Two things this incident proves beyond the first: (1) any
  fix based on "clear/rotate the handoff at dispatch start" is **defeated outright** by a
  git-restore, since clearing already happened and the file came back anyway — this directly rules
  out WORK item (d)'s candidate direction (b) from task 53's own description; (2) **the recovery
  fallback (`orchestrate-recover-outcome.sh`) shares the same exposure and is currently
  UNGUARDED** — its `.return-meta.json` staleness check is mtime-windowed only, with no
  `dispatch_seq` equivalent, which is precisely WORK item (b)'s stated requirement.

The **spurious-defect case** the writer-contract-aware recording (d) must suppress is a *third*,
distinct, non-incident scenario, also in task 53's original description: a clean, fully-successful
base-mode run where the planner's `dispatch_seq=1` handoff is never cleared, the following implement
dispatch (a **contractual non-writer** in base mode — see Handoff Writers table below) correctly
writes none, and both gates fire on the planner's leftover file, recording a defect on a run in
which nothing went wrong.

These three scenarios are the natural fixture set for ACCEPTANCE (1) mtime-stale, (2)
`dispatch_seq`-mismatched, (3) git-restored-predecessor (recovery path), and (4)
contractual-non-writer-vs-genuine-late-write discrimination.

### `user_decision` Relay (WORK item (e))

Fully specified in `agent-system/extensions/core/context/standards/user-decision-contract.md`:
`{question, options, recommended, blocking}`, producer-owned (never overwritten by a later
writer), read off `.return-meta.json` or the handoff. The contract explicitly assigns the
postflight script's role: *"reads `user_decision` off `.return-meta.json` (or the handoff, when
present) and relays it as an `ask_user` verdict... never by re-deriving or rephrasing the agent's
question/options/recommended text."* specs/PATH.md additionally specifies where the *answer* is
persisted — `specs/{NNN}_{slug}/.decisions.json`, written by the lead, carried into the next
dispatch file by `orchestrate-build-dispatch.sh` (146, already landed) — but **that write path is
explicitly the lead's job, not this script's**: "The script never asks and never decides." No
`.decisions.json` file or writer exists anywhere in the codebase yet (confirmed by grep); this
script's sole obligation for (e) is reading the field, if present, and relaying it unmodified in
the output JSON's `verdict`/`user_decision` fields while leaving `status` exactly as the agent left
it.

### `modified_files` vs `file_scope` Excursion Advisory (WORK item (h))

Fully specified by absorbed task 100: compare each task's `.return-meta.json` `modified_files[]`
(already accurate, agent-authored) against the task's declared `file_scope[]` (state.json,
descriptive/anticipated per `context/reference/state-management-schema.md`'s File Scope field) and
log any path outside it. Task 100's own recommendation is **direction (a) only**: detection/logging,
no gate change — matching this task's own MUST NOT ("no gate change") exactly. This is a
straightforward set-difference check with no live precedent script yet; `file_scope` is read from
`specs/state.json` per task, `modified_files` from that task's own `.return-meta.json`.

### Writer-Contract Determination (needed for WORK item (d))

`agent-system/extensions/core/docs/architecture/handoff-schema.md`'s "Handoff Writers" table is
the closest existing artifact to a machine-checkable writer-contract source:

| Writer | Contractual writer? |
|---|---|
| Base-mode `general-research-agent`, `planner-agent`, `general-implementation-agent` (used for BOTH standard and hard-mode dispatch on **core** task types: general/meta/markdown) | Never — no `routing_agents_hard` override exists for core any more |
| cslib and lean hard-mode implementation-agent counterparts | Active writer (only under `--hard`, implement phase) |
| Any research-phase dispatch, any task type, any mode | Never (Stage 3.6 "Scoping Decision" prohibits it categorically) |

This table is **not yet expressed as code** anywhere — it lives only as prose in the doc and as the
`routing_agents_hard` manifest declarations extensions carry. See "Open Design Question" below for
why phase-alone is insufficient and what the script needs instead.

### External Resources

None consulted — this is a pure in-repo consolidation task with no external library or API
surface; every dependency is another script or SKILL.md region in this same repository.

## Decisions

None made by this research pass beyond scope confirmation — the dispatch file and specs/PATH.md
already settle the WORK item breakdown, script name, CLI shape, and output schema. The one item
genuinely left open for the plan to decide is below.

## Open Design Question (for the plan to resolve, not decided here)

**How does the new script determine, per dispatch identity, whether THIS dispatch's own writer was
contractually expected to write a handoff?**

The dispatch file is explicit that this must be "keyed on dispatch identity (dispatch_seq) and not
on phase alone." A naive `phase == "implement" → never a writer` rule is **wrong** for cslib/lean
under `--hard`, and would silently re-swallow both evt_ incidents (both were hard-mode implement
dispatches whose own agent WAS a contractual writer — the defect there was a genuine seq-mismatched
clobber, not an expected absence). The correct predicate needs at minimum: `task_type`,
`hard_mode`/effort mode for *this specific dispatch* (not the task's current mode toggle, in case
that ever varies mid-task), and phase — the same three inputs `routing_agents_hard` resolution
already keys on. Two candidate sources for this, neither wired into any script today:

1. Re-derive the same resolution the dispatch-composer (`orchestrate-build-dispatch.sh`, 146)
   already performed when it picked the agent for this dispatch_seq — if that script records which
   agent it dispatched (by name) into the multi-state/loop-guard file alongside `dispatch_seq[t]`,
   the postflight script can look up "is `<agent_name>` a hard-mode-implement-writer" via a small,
   explicit allowlist (today: cslib and lean's hard-mode implementation agents only) rather than
   re-deriving task_type/hard_mode/phase resolution independently in a second place.
2. Re-run the manifest routing lookup itself (`command-route-agent.sh` / the shared
   `manifest-routing-lib.sh` ladder) with this dispatch's own recorded `(task_type, phase,
   effort_flags)` and compare the resolved agent name against the resolved base-mode agent name for
   the same `(task_type, phase)` — if they differ, this dispatch's agent is a hard-mode-specific
   writer.

Option 1 is cheaper and matches this repo's actual writer set (only two named agents), but is a
hardcoded allowlist that silently goes stale if a third extension adds a hard-mode writer. Option 2
is more general but re-executes routing logic the dispatch already resolved once. Recommend the
plan pick explicitly and record the choice — this is exactly the kind of two-reasonable-designs
fork `context/standards/user-decision-contract.md` describes, but it is an **implementation**
decision the agent should make and record (codebase convention doesn't yet answer it), not a
`user_decision` to raise with the human.

## Risks & Mitigations

- **`.return-meta.json` has no `dispatch_seq` field today.** WORK item (b) requires
  `orchestrate-recover-outcome.sh` to gain "the same dispatch_seq identity check it lacks today."
  Since base-mode research/plan/implement dispatches never write a handoff, the ONLY place a
  `dispatch_seq` could be echoed back for comparison is `.return-meta.json` itself — meaning this
  task's scope implicitly includes adding a `dispatch_seq` field to the `.return-meta.json` schema
  (`context/formats/return-metadata-file.md`) and to every agent contract that writes it (general-
  research/implementation-agent, planner-agent, at minimum). This is a real schema change, not a
  pure script change, and should be sized accordingly in the plan. Mitigation: without this field,
  the git-restored-predecessor shape (evt_Fodegl) is only guardable via mtime on the
  `.return-meta.json` path (the *existing* insufficient defense) — the plan must either add the
  field or explicitly accept a narrower fix (mtime-only) for `.return-meta.json` recovery while
  keeping the full gate for the handoff path, and say which.
- **Scope size.** This is not an incremental patch; it is a new ~150-300 line script absorbing the
  combined logic of three existing scripts (845 lines) plus ~250 lines of SKILL.md MT-4/MT-5 inline
  prose, plus three genuinely new behaviors. Recommend the plan phase this explicitly (e.g., gates
  + recovery seq-check first, then corroboration + writer-contract recording, then artifact
  link/round-advance + excursion advisory, then commit/multi-state/lock tail) rather than one
  single-shot rewrite, mirroring how 146/147 were each landed as one clean cycle-script apiece.
  Both engines (single-task Stage 5/postflight and multi-task MT-4/MT-5) must keep calling the OLD
  scripts until the new one is proven, then cut over — the dispatch's own MUST-NOT ("read report,
  plan, summary or handoff prose"; "weaken either gate") plus the ACCEPTANCE bar ("both engines
  visibly agree on the gate semantics") both anticipate a transitional period where old and new
  code coexist.
- **The mtime staleness gate's fail-closed default (`9999999999`) is a shared, load-bearing
  constant** across `orchestrate-stage5-gates.sh`, `orchestrate-recover-outcome.sh`, and SKILL.md
  Stage 5 inline code — the new script must preserve it exactly, not re-derive a different
  sentinel.
- **`dispatch-seq-gate:begin`/`:end` sentinel region is locked** per
  `specs/055_dedupe_orchestrate_skill_bodies/locked-regions.md` (not read directly this pass, but
  referenced three times in the surrounding SKILL.md comments) — moving this logic into the new
  script changes what lives inside vs. outside that region; the plan should check that file before
  editing SKILL.md's Stage 5, since `test-handoff-dispatch-identity.sh` extracts and `eval`s that
  exact region by sentinel today and will need updating or retargeting at the same time.

## Context Extension Recommendations

- **Topic**: writer-contract determination (per-dispatch, not per-phase).
  **Gap**: `docs/architecture/handoff-schema.md`'s "Handoff Writers" table is prose-only; no script
  or shared function resolves "is this specific dispatch's agent a contractual handoff writer"
  today.
  **Recommendation**: once the plan picks one of the two options above, document the chosen
  resolution mechanism in `docs/architecture/handoff-schema.md` itself, next to the existing table,
  so a future writer addition (a third extension's hard-mode agent) has one place to register.

## Appendix

### Search Queries / Commands Used

- `grep -n "^## Stage\|^### Stage\|dispatch_seq\|handoff_stale\|dispatch_start_ts" skill-orchestrate/SKILL.md`
- Direct reads: `orchestrate-stage5-gates.sh`, `orchestrate-stage5-postflight.sh`,
  `orchestrate-recover-outcome.sh` (full files), SKILL.md Stage 5 (1727-2091), Stage MT-4
  (2729-3187), `orchestrate-cycle-plan.sh` (header + CLI parser), `skill-base.sh` (postflight
  update, corroborate-phase-counts, mint-dispatch-seq, append-detected-defect, propagate-completion
  functions).
- `jq` queries against `specs/archive/state.json` for tasks 53, 100, 138 (full abandoned
  descriptions, the source of the incident detail and absorbed-gap mapping above).
- `grep -rn "\.decisions\.json"` (repo-wide, zero hits — confirms this write path is unbuilt).

### References

- `specs/PATH.md` — "The four moves per cycle" (line ~152), Stage A table (A.4, line ~236),
  backlog manifest entries for 143/53/100/138.
- `agent-system/extensions/core/context/standards/user-decision-contract.md` (full file read).
- `agent-system/extensions/core/docs/architecture/handoff-schema.md` (Handoff Writers section,
  lines 386-408).
- `agent-system/extensions/core/context/formats/return-metadata-file.md` (status vocabulary,
  artifacts shape — confirms no `dispatch_seq` field exists).
