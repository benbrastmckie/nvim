# Research Report: Task #635

**Task**: 635 - Enforce the sapience postflight wrapup write
**Started**: 2026-11-17T00:00:00Z
**Completed**: 2026-11-17T00:00:00Z
**Effort**: medium
**Dependencies**: None
**Sources/Inputs**:
- Codebase: `agent-system/extensions/sapience/**` (EXTENSION.md, per-repo-scoping.md,
  review-gate-boundary.md, sapience-remember.sh, sapience-write-path.md, test-sapience-capture.sh)
- Codebase: `agent-system/extensions/core/scripts/skill-base.sh`, `orchestrator-postflight.sh`,
  `orchestrate-cycle-postflight.sh`, `reconcile-task-status.sh`, `update-task-status.sh`,
  `issue-record.sh`, `events-append.sh`
- Codebase: `agent-system/extensions/core/agents/general-implementation-agent.md`
- Codebase: `agent-system/extensions/core/context/formats/return-metadata-file.md`,
  `issue-log.md`, `report-format.md`
- `.claude-extensions.json` (source_dir resolution for `sapience` and `core`)
**Artifacts**:
- `specs/635_enforce_sapience_postflight_wrapup_write/reports/01_sapience-postflight-wrapup-enforcement.md`
**Standards**: report-format.md, return-metadata-file.md, issue-log.md, sapience-write-path.md

## Executive Summary

- The wrapup write's only call site today is prose in `EXTENSION.md` at the
  `[IMPLEMENTING]` -> `[COMPLETED]` transition. No manifest `hooks.postflight` entry can ever
  fire for it (sapience declares no `task_type`), and no live script or agent file greps for
  `sapience` at any completion call site — the measured intermittency in the dispatch is fully
  explained by this being pure, skippable instruction text.
- The live completion machinery already has an exact structural precedent for mechanizing an
  agent-authored, bounded array into a propagation write: `memory_candidates`
  (`general-implementation-agent.md` Stage 6b -> `.return-meta.json` top-level field ->
  `skill_propagate_memory_candidates` in `skill-base.sh`). Recommend a sibling top-level field
  `sapience_notes` and a sibling function `skill_propagate_sapience_notes`, calling
  `sapience-remember.sh` once per note instead of writing to `state.json`.
- **There is no single call site that reaches both the live orchestrate path and the deferred
  reconcile path.** `skill_postflight_update` (`skill-base.sh:1010`) is the one function both
  `orchestrate-cycle-postflight.sh` and the single-task `command-gate-out.sh` path call for the
  implement status transition, but `reconcile-task-status.sh`'s deferred promotion branches
  (`implementing)` at line 656, `partial)` at line 696 — the exact task-626 deploy-gate-refusal
  shape) call `update-task-status.sh postflight ... implement` **directly**, bypassing
  `skill_postflight_update` entirely. The new propagation call must therefore be wired at **two**
  call sites, not one.
- A related, pre-existing, out-of-scope gap: `reconcile-task-status.sh`'s deferred promotion
  branches never call `skill_orchestrate_propagate_completion`/`skill_propagate_completion_summary`
  either — `completion_summary`/`roadmap_items` are not back-filled on the deferred path today.
  This is evidence the new design must read `sapience_notes` directly off the task's own
  `.return-meta.json` at each call site, never by riding along on a propagation path reconcile
  does not already exercise.
- `sapience-remember.sh` and its `--dry-run` shape already exist and are already covered by
  `agent-system/extensions/sapience/scripts/tests/test-sapience-capture.sh` cases 10-12. No
  change to that script is needed; only a new call site and a new test exercising that call site
  (stubbing `sapience-remember.sh` itself, not `curl`) are required.
- `issue-record.sh`'s open-enum `class` field is the correct mechanism for GOAL (2)'s "visible,
  non-blocking gap" requirement, mirroring the already-established
  `infrastructure/transport unavailable` degrade pattern used at the retrieval call site.

## Context & Scope

Task 635 asks this research phase to locate the mechanical anchor point(s) for enforcing the
Sapience postflight wrapup write (currently a prose-only instruction in `EXTENSION.md`) and to
recommend a design satisfying all five GOAL sub-points in the dispatch:

1. decide and implement where the write is mechanically anchored (agent emits a bounded array;
   a shared postflight script calls `sapience-remember.sh`),
2. zero notes recorded as a visible, non-blocking gap,
3. the 3-8 bound enforced at that one site,
4. the mechanism must also work on the deferred-completion path task 626 took (a
   deploy-gate refusal later settled by `reconcile-task-status.sh`),
5. `per-repo-scoping.md` and `EXTENSION.md` updated to state the resulting design, with tests
   stubbing the network call (`--dry-run`).

Edit targets are the source store: `agent-system/extensions/sapience/**` and
`agent-system/extensions/core/**` (never the deployed `.claude/**` mirror), resolved via
`.claude-extensions.json`'s `.extensions.sapience.source_dir` /
`.extensions.core.source_dir`, both confirmed present and `active`:

```
sapience -> /home/benjamin/.config/nvim/agent-system/extensions/sapience
core     -> /home/benjamin/.config/nvim/agent-system/extensions/core
```

This research phase does not implement the change; it establishes the precise call sites,
existing conventions to mirror, and a sized design for the plan phase.

## Findings

### 1. The only existing call site is prose, and it is genuinely unreachable mechanically

`agent-system/extensions/sapience/EXTENSION.md`'s "Postflight wrapup" paragraph is the sole
instruction naming `sapience-remember.sh` as a write-at-completion step. A repo-wide grep for
`sapience` across every agent file (`agent-system/extensions/*/agents/*.md`) and every core
postflight script (`orchestrator-postflight.sh`, `orchestrate-cycle-postflight.sh`,
`orchestrate-stage5-postflight.sh`, `reconcile-task-status.sh`, `skill-base.sh`,
`update-task-status.sh`) returns **zero** hits outside `orchestrate-build-dispatch.sh`'s
`sapience-retrieve.sh` call (the read side, Stage 3.5 `memory_context`, unrelated to the write).
This directly confirms the dispatch's measured finding (session `sess_1794696615_44948d`
completing tasks 436 and 626 with no `sapience-remember.sh --subject` invocation across 12
subagent transcripts): nothing short of an agent voluntarily reading and following prose text
would ever invoke the write.

`per-repo-scoping.md`'s own "No Lifecycle Hook" section already documents why the obvious fix
(a manifest `hooks.postflight` entry) cannot work: `skill_get_extension_dir()` in
`skill-base.sh` gates hook resolution on `[ -n "$ext_task_type" ] && [ "$ext_task_type" =
"$task_type" ]`, and sapience deliberately declares no `task_type` (it applies to every task
regardless of domain), so the `-n` test fails unconditionally. This is correct and remains true
— the fix in this task is **not** to force a manifest hook, but to anchor the call inside a
function that already runs unconditionally for every implement completion, independent of the
extension-hook dispatch mechanism entirely.

### 2. `memory_candidates` is the exact structural precedent to mirror

`general-implementation-agent.md` Stage 6b ("Emit Memory Candidates", line 833) has the agent
emit `0-3` structured objects (`content`, `category`, `source_artifact`, `confidence`,
`suggested_keywords`) into a top-level `memory_candidates` array in `.return-meta.json` (Stage 7,
line 860: "Include `memory_candidates` array ... at the top level of the JSON output"). This is
consumed by `skill_propagate_memory_candidates` (`skill-base.sh:1223`), a four-line function that
appends the array onto `state.json` via `state-write.sh`.

`sapience_notes` should be built identically: agent-authored content (never mechanically
generated), a sibling top-level array field, consumed by a sibling propagation function — except
the consumer calls an external script per entry instead of writing to `state.json`.
`return-metadata-file.md`'s existing field table already documents the "sibling top-level field,
never nested under `completion_data`" convention for `memory_candidates` (lines 443, 533, 612,
646) and the same placement is correct for `sapience_notes`: `completion_data` is specifically
`completion_summary`/`roadmap_items`, state.json-bound fields; `sapience_notes` is a
script-invocation payload, structurally identical in shape to `memory_candidates`, not to
`completion_data`.

### 3. The live completion-transition machinery has two independent call sites, not one

Tracing every live caller of the implement->completed state transition (not the *dead*
`orchestrator-postflight.sh`, whose own header comment at line 34 states "research and plan only;
implement does inline" and whose Stage 7b/7c comments note it "has no current caller" — confirmed
by `grep -rn` finding no invocation of that script anywhere in `scripts/*.sh` or
`skill-orchestrate/SKILL.md`):

| Path | Mechanism | File:line |
|------|-----------|-----------|
| Normal `/orchestrate` single/multi-task completion | `skill_postflight_update "$task_number" "implement" ...` | `skill-base.sh:1010`, called from `orchestrate-cycle-postflight.sh:1390,1439,1442,1483` and `orchestrate-stage5-postflight.sh:161` |
| Single-task command completion | same function, via `command-gate-out.sh:203,305` | `command-gate-out.sh` |
| **Deferred** completion (stranded `implementing`/`partial` with a summary artifact on disk — task 626's exact shape) | `update-task-status.sh postflight "$task_number" implement "$session_id" --phase-check=refuse` called **directly**, bypassing `skill_postflight_update` | `reconcile-task-status.sh:684` (`implementing)` arm, line 656) and `reconcile-task-status.sh:734` (`partial)` arm, line 696) |

Both paths ultimately invoke the same underlying `update-task-status.sh postflight ... implement`
status write (`map_status()`'s `postflight:implement) STATE_STATUS="completed"` row,
`update-task-status.sh:503`), and both pass through the same unconditional Phase 0.5
completion-deploy gate in that script (the `exit 6` refusal task 626 actually hit). But the
*propagation* logic that runs **after** a successful status write diverges completely: the live
path calls `skill_orchestrate_propagate_completion` (`skill-base.sh:1083`, called from
`orchestrate-cycle-postflight.sh:1439,1442` and `orchestrate-stage5-postflight.sh:168`), which
reads `completion_summary`/`roadmap_items` off `.return-meta.json` and writes them via
`skill_propagate_completion_summary`; the deferred reconcile path calls **neither** — a grep of
`reconcile-task-status.sh` for `propagate|completion_summary|memory_candidates` returns no
matches at all.

**Consequence for this task's design**: there is no existing shared choke point to piggyback on.
A new propagation call for `sapience_notes` must be wired independently at:
(a) `orchestrate-cycle-postflight.sh`'s `implemented)` case, specifically the branch(es) where
`skill_postflight_update` returns rc 0 **and** the resolved status is the true terminal
`implemented` (not the `partial`/`warn` sub-arms at lines 1390/2138, which keep the task at
`implementing`/`partial` rather than `completed`) — i.e. alongside the existing
`skill_orchestrate_propagate_completion` calls at lines 1439 and 1442; and
(b) `reconcile-task-status.sh`'s `implementing)` (line 684-695) and `partial)` (line 734-742)
arms, immediately after `update-task-status.sh postflight` succeeds (`reconcile_rc` not 4, not
non-zero) — i.e. right where those arms already log `"promoted ... -> completed"`.

Each call site should read `sapience_notes` directly from that task's own `.return-meta.json`
(already on disk, already read for other fields at both sites) rather than depending on any
value threaded through `orchestrate-recover-outcome.sh` or `skill_orchestrate_propagate_completion`
— exactly because the reconcile path does not exercise that machinery, per the prior paragraph's
finding. A single new shared function, e.g. `skill_propagate_sapience_notes "$task_number"
"$sapience_notes_json" "$task_dir" "$session_id"` in `skill-base.sh`, called independently from
both sites (mirroring how `skill_propagate_memory_candidates` and
`skill_propagate_completion_summary` are each standalone, independently-called functions rather
than nested inside `skill_postflight_update`), keeps the bound-enforcement and
sapience-remember.sh-invocation logic in exactly one place while tolerating the two call sites'
structural divergence.

**A related, out-of-scope observation**: `skill_propagate_memory_candidates` itself has **zero**
live callers anywhere in `scripts/*.sh` or `skill-orchestrate/SKILL.md` today (confirmed by
`grep -rln`) — `memory_candidates` is written to `.return-meta.json` by the implementation agent
but never actually propagated to `state.json` on any currently-exercised path. This is a
pre-existing gap independent of sapience and not something this task should fix, but it is
directly relevant evidence for the design principle above: "a function exists in `skill-base.sh`"
is not proof a given completion path calls it. The new `skill_propagate_sapience_notes` wiring
must be verified by grepping its own call sites after implementation, not inferred from the
function's mere existence.

### 4. `sapience-remember.sh` already has everything the call site needs

`agent-system/extensions/sapience/scripts/sapience-remember.sh` already implements exactly the
shape EXTENSION.md's prose prescribes: `--subject S --value V [--predicate P] [--ko-type T]
[--confidence C] [--source-loc L] [--dry-run]`, mandatory `explicit: true`, loud non-zero exits on
`gated`/`set_aside`/`written==0`/`ok!=true`, and a `[repo:<slug>]`-tagged `provenance`. No change
to this script is required. The call site's job is purely: for each of the agent's `sapience_notes`
entries (bound-enforced, see below), invoke this script once, non-fatally, mapping entry fields
onto its flags (`subject`, `value`, optionally `predicate`/`ko_type`/`confidence`/`source_loc`),
and on a non-zero exit, mirror the failure via `issue-record.sh --class "infrastructure/transport
unavailable"` — reusing the exact class and phrasing `EXTENSION.md`'s own prose already names,
and the exact pattern `orchestrate-build-dispatch.sh:372` already uses for the read-side
(`sapience-retrieve.sh`) degrade.

### 5. The 3-8 bound is enforceable only as an upper-bound truncation; the lower bound cannot be mechanically fixed

The call site can truncate an agent-emitted array longer than 8 entries (call
`sapience-remember.sh` for only the first 8, loudly warning on stderr and recording a non-fatal
`issue-record.sh` entry so an agent that routinely over-emits is visible to the conclusion
stage). It **cannot** mechanically raise a 1-2 entry array to the 3-entry floor — there is no
content to fabricate. The floor is therefore necessarily agent-side guidance only (mirrored into
the new Stage 6c instructions below), while the ceiling (8) and the all-zero case (GOAL 2) are
the two conditions the call site can and must enforce mechanically:

- **Ceiling (>8)**: truncate to the first 8, non-fatal `issue-record.sh` entry, class
  `tooling bug or gap` (an agent not respecting its own documented bound), severity `minor`.
- **Zero**: skip the per-note loop entirely and record exactly one non-fatal `issue-record.sh`
  entry with a new open-enum class (GOAL 2's "visible, non-blocking gap, never silent"). Reusing
  `infrastructure/transport unavailable` would be **wrong** here — that class is reserved for a
  backing-service failure, not an agent producing no notes — so a new class name is warranted,
  e.g. `sapience wrapup: zero notes` (see Recommendations).
- **1-8 (the normal range)**: no gap entry; each `sapience-remember.sh` call that itself fails is
  individually mirrored via the existing `infrastructure/transport unavailable` class, exactly as
  `EXTENSION.md`'s prose already specifies ("A non-zero exit ... is MIRRORED non-fatally via
  `issue-record.sh`").

### 6. `issue-record.sh` is the correct GOAL-(2) mechanism, not `events-append.sh`

`events-append.sh` is session/cycle telemetry with a closed four-category enum
(`deviation|blocker|milestone|success`) feeding lifecycle/notification tooling, not the
conclusion-stage review pipeline. `issue-record.sh` writes to the per-task, append-only
`issues.jsonl`, whose explicit purpose (`issue-log.md`) is exactly "capture, reviewed exclusively
by the orchestration conclusion stage" — the same pipeline the existing degrade pattern at the
retrieval call site already uses. Both the zero-notes gap and any individual write failure should
go through `issue-record.sh`, consistent with the one call-site precedent this codebase already
has for a Sapience-adjacent non-fatal degrade.

### 7. Testing precedent: stub the script under test, not `curl`, for call-site tests

`test-sapience-capture.sh` cases 10-12 already prove `sapience-remember.sh --dry-run` produces a
correctly-tagged, token-redacted, `explicit:true` body with **no** `curl` stub installed at all
— the script's own `--dry-run` short-circuit makes "no network call" an assertion, not an
assumption. A new test for the call-site wiring (the propagation function, and its two call
sites) should follow the same discipline one level up: PATH-shadow `sapience-remember.sh` itself
(a thin recording stub that logs its argv and exits 0/1/2 on command) rather than reaching through
to the real script's `--dry-run` path, so the test can assert call *count* (bound enforcement)
and *argument shape* (subject/value mapping) independent of the real script's own already-tested
behavior. A natural home for this new suite is
`agent-system/extensions/core/scripts/tests/test-postflight-sapience-notes.sh`, since the subject
under test (`skill_propagate_sapience_notes`, its call sites) is core, not sapience.

## Decisions

- **`sapience_notes` is a sibling top-level `.return-meta.json` array field**, structurally
  identical in placement convention to `memory_candidates` (never nested under
  `completion_data`), agent-authored by `general-implementation-agent.md` in a new Stage 6c
  ("Emit Sapience Notes") immediately after Stage 6b, with the same `0-3`-style cardinality
  framing replaced by a `3-8` floor/ceiling instruction (agent-side guidance; mechanically
  enforced only at the ceiling — see Findings 5).
- **The mechanical anchor is a new shared function, `skill_propagate_sapience_notes`, in
  `agent-system/extensions/core/scripts/skill-base.sh`**, mirroring
  `skill_propagate_memory_candidates`'s signature/placement convention but calling
  `sapience-remember.sh` once per note instead of `state-write.sh`. It is **not** nested inside
  `skill_postflight_update` (mirroring how `skill_orchestrate_propagate_completion` is already a
  standalone sibling call, never folded into that function) and is **not** attempted as a
  manifest `hooks.postflight` entry (per-repo-scoping.md's existing, still-correct "No Lifecycle
  Hook" finding).
- **Two call sites are required, not one**: `orchestrate-cycle-postflight.sh`'s `implemented)`
  terminal arms (alongside the existing `skill_orchestrate_propagate_completion` calls) for the
  live path, and `reconcile-task-status.sh`'s `implementing)`/`partial)` promotion arms (after a
  successful `update-task-status.sh postflight` call) for the deferred path task 626 took. Each
  site independently reads `sapience_notes` off that task's own `.return-meta.json` rather than
  depending on a value threaded through machinery the reconcile path does not exercise.
- **Bound enforcement is upper-only at the mechanical site** (truncate to 8, non-fatal
  `issue-record.sh` entry); the 3-note floor is agent-side guidance that cannot be mechanically
  enforced and is not attempted here.
- **Zero notes is its own distinct `issue-record.sh` class**, not a reuse of
  `infrastructure/transport unavailable` (that class is reserved for genuine backing-service
  failure, and conflating the two would make the conclusion stage unable to distinguish "agent
  produced nothing" from "Sapience was down").
- **No change to `sapience-remember.sh` itself** — it already implements every behavior the call
  site needs.

## Recommendations

1. **Core, `return-metadata-file.md`**: add a `sapience_notes` field specification sibling to the
   existing `memory_candidates` entry — array of `{subject, value, predicate?, ko_type?,
   confidence?, source_loc?}` objects, each key mapping 1:1 onto `sapience-remember.sh`'s own
   flags, top-level (never nested under `completion_data`), producer = the completing
   implementation agent.
2. **Core, `general-implementation-agent.md`**: add Stage 6c "Emit Sapience Notes" immediately
   after Stage 6b (line 833 region), instructing the agent to distill 3-8 notes (reusing the same
   "what to capture / what not to capture" framing Stage 6b already uses, adapted for
   cross-session durable findings rather than in-repo memory candidates) into the
   `sapience_notes` array; update the Stage 7 write-up line (860) to also mention
   `sapience_notes` at the top level.
3. **Core, `skill-base.sh`**: add `skill_propagate_sapience_notes "$task_number"
   "$sapience_notes_json" "$task_dir" "$session_id"`, modeled on
   `skill_propagate_memory_candidates` (`skill-base.sh:1223`)'s structure/doc-comment
   conventions: for 1-8 entries call `sapience-remember.sh` once per entry non-fatally, mirroring
   any individual failure via `issue-record.sh --class "infrastructure/transport unavailable"`;
   for >8 entries truncate to the first 8 with a loud stderr warning plus an `issue-record.sh`
   entry (class `tooling bug or gap`, severity `minor`); for exactly 0 entries, skip the loop and
   record one `issue-record.sh` entry (new class — see Decision above, severity `minor`,
   `what_happened` naming the task and that no sapience notes were emitted at completion).
4. **Core, wiring**: call the new function from both `orchestrate-cycle-postflight.sh`'s true
   `implemented` terminal arms (next to the existing `skill_orchestrate_propagate_completion`
   calls at lines 1439/1442) and from `reconcile-task-status.sh`'s `implementing)`/`partial)`
   promotion arms (after the `update-task-status.sh postflight` success branch, lines ~695/~742),
   each site resolving `$task_dir` and `$session_id` from variables it already has in scope.
5. **Core, tests**: add `agent-system/extensions/core/scripts/tests/test-postflight-sapience-notes.sh`,
   PATH-shadowing a recording `sapience-remember.sh` stub (not `curl`), covering: N=0 (one gap
   issue row, zero script calls), N in [1,8] (exactly N calls, correct subject/value mapping),
   N>8 (exactly 8 calls, one truncation issue row), and one stubbed script failure within an
   otherwise-normal N (one mirrored `infrastructure/transport unavailable` issue row, the
   remaining notes still attempted — non-fatal per-note, not an abort-on-first-failure loop).
6. **Sapience, `EXTENSION.md`**: replace the "Postflight wrapup" paragraph's description of the
   write as an instruction the orchestrator follows with a description of it as a mechanically
   anchored write: the implementing agent emits `sapience_notes`; `skill_propagate_sapience_notes`
   (core) performs the call; the bound and the zero-notes gap are enforced at that one site, not
   by agent discipline.
7. **Sapience, `per-repo-scoping.md`**: update "The Tagged-Write Call Site" to name
   `skill_propagate_sapience_notes` and its two call sites instead of "`EXTENSION.md`'s postflight
   wrapup instruction"; leave "No Lifecycle Hook" substantively as-is (its reasoning is still
   correct) but add one sentence noting the new mechanism sidesteps the manifest-hook gating
   entirely by living inside core's own unconditional postflight functions rather than depending
   on `hooks.postflight` dispatch.
8. **No task-number references, no record-versioning language** in any edited file under
   `agent-system/**`, per the dispatch's own constraint and this repo's standing rules
   (`no-task-references-in-deliverables.md`, `no-record-versioning-in-deliverables.md`) — state
   the resulting design on its own merits, not as "replacing" or "superseding" the prior prose in
   a way that narrates draft history beyond the one sanctioned "replacing the untagged
   `sapience_wrapup` call" framing `EXTENSION.md` already uses today for the *other* Write-Tool
   Disposition decision (D3), which is a real design decision, not a draft-lineage note.

## Risks & Mitigations

- **Risk**: wiring only one of the two call sites (the common mistake this research explicitly
  surfaced) silently leaves the deferred path exactly as unreachable as the prose instruction is
  today. *Mitigation*: Decisions/Recommendation 4 name both sites explicitly; the plan phase
  should require a grep-based self-check (mirroring `report-format.md`'s own pre-return grep
  discipline) confirming `skill_propagate_sapience_notes` has exactly two call sites before
  closing the implementation.
- **Risk**: every `sapience-remember.sh` write is permanent (no delete API) and unreviewed
  (bypasses `auto_approve: false`) — per `per-repo-scoping.md`'s Hazards section. A bug in the
  new propagation function (e.g. looping on a malformed array) could write far more than 8 notes
  before anyone notices. *Mitigation*: the ceiling truncation in Recommendation 3 is a hard
  array-length check performed before any `sapience-remember.sh` call is issued, not a running
  counter that could be bypassed by a malformed shape; the new test suite's N>8 case exists
  specifically to catch a regression here.
- **Risk**: the new `sapience_notes` field could be confused with `memory_candidates` by a future
  editor, given their structural similarity. *Mitigation*: the `return-metadata-file.md` field
  spec (Recommendation 1) should state explicitly that the two are destined for different stores
  (local `state.json` vs. the hosted Sapience vault) and are not interchangeable, mirroring how
  the existing memory-extension retargeting (recorded as prior-session memory context for this
  dispatch) already distinguishes hosted-vault writes from local-vault writes.
- **Risk**: PR-type tasks transition `[PR READY]` -> `[COMPLETED]` via `postflight:pr_ready`
  (`update-task-status.sh:505`), a third status-mapping row this research did not trace end to
  end. *Mitigation*: out of scope for this task's measured evidence (both task 436 and task 626
  are non-PR completions); flag for the plan phase to decide whether `postflight:pr_ready`'s own
  call site (also user-invoked, per `pr-prohibition.md`) needs the same wiring, or whether the
  preceding `implementing -> pr_ready` dispatch already emitted its notes.

## Context Extension Recommendations

- **Topic**: live-caller verification for `skill-base.sh` propagation functions.
- **Gap**: this research found a function (`skill_propagate_memory_candidates`) that exists,
  is fully implemented, and has zero live callers — a shape that is easy to mistake for "already
  wired" from the function's existence alone. No context file currently documents a check (e.g.
  "before trusting a `skill_propagate_*` function is wired, grep its own name across
  `orchestrate-cycle-postflight.sh`/`reconcile-task-status.sh`/`orchestrate-stage5-postflight.sh`,
  never infer from the function's presence in `skill-base.sh`") that would have made this
  discoverable without a full trace.
- **Recommendation**: add a short subsection to
  `agent-system/extensions/core/context/patterns/` (or a note in
  `return-metadata-file.md`'s "Multiple Sequential Writers" section) naming this verification
  step, so a future task adding a new `.return-meta.json`-propagated field does not assume
  "defined in `skill-base.sh`" implies "called from every completion path."

## Appendix

- Search queries / commands used: `grep -rn sapience` across agent files and core postflight
  scripts; `grep -n "skill_propagate_completion_summary\|skill_orchestrate_propagate_completion\|skill_postflight_update\|update-task-status.sh postflight"` across `agent-system/extensions/core/scripts/*.sh`; direct reads of `EXTENSION.md`, `per-repo-scoping.md`, `review-gate-boundary.md` (Write-Tool Disposition), `sapience-write-path.md`, `sapience-remember.sh`, `test-sapience-capture.sh`, `return-metadata-file.md` (`completion_data`, `memory_candidates` sections), `issue-log.md` (seed class enum), `general-implementation-agent.md` (Stages 6/6a/6b/7), `reconcile-task-status.sh` (implementing/partial arms), `update-task-status.sh` (map_status, Phase 0.5 deploy gate).
- Key file:line references: `agent-system/extensions/sapience/EXTENSION.md` (postflight wrapup
  paragraph); `agent-system/extensions/sapience/context/project/sapience/domain/per-repo-scoping.md`
  ("The Tagged-Write Call Site", "No Lifecycle Hook", "D3"); `agent-system/extensions/core/scripts/skill-base.sh:1010` (`skill_postflight_update`), `:1083` (`skill_orchestrate_propagate_completion`), `:1223` (`skill_propagate_memory_candidates`), `:1313` (`skill_propagate_completion_summary`); `agent-system/extensions/core/scripts/orchestrate-cycle-postflight.sh:1390,1439,1442,1483,2138`; `agent-system/extensions/core/scripts/reconcile-task-status.sh:656-699,696-744`; `agent-system/extensions/core/scripts/update-task-status.sh:503` (`map_status`), `:868-930` (Phase 0.5 deploy gate); `agent-system/extensions/core/agents/general-implementation-agent.md:833-860`; `agent-system/extensions/sapience/scripts/tests/test-sapience-capture.sh` (cases 10-12).
