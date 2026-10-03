# Research Report: Surface skeleton-plan follow-ups at completion under the batch engine

- **Task**: 184 - Surface skeleton-plan follow-ups at completion under the batch engine (ruled: port the sorry_inventory follow-up report, not pr_ready routing)
- **Started**: 2026-10-03T04:12:00Z
- **Completed**: 2026-10-03T04:50:00Z
- **Effort**: ~1.5 hours
- **Dependencies**: 242, 243 (both archived/complete — same postflight script/test and handoff-schema.md respectively; no live conflict)
- **Sources/Inputs**:
  - Codebase: `orchestrate-cycle-postflight.sh`, `orchestrate-cycle-plan.sh`, `skill-base.sh`, `handoff-schema.md`, `wrap-up.md`, `status-markers.md`, `state-management-schema.md`, `recovery.md`, `test-orchestrate-cycle-postflight.sh`
  - `specs/state.json` task entry (description carries the 2026-09-22 ruling verbatim)
  - `specs/088_.../summaries/01_four-move-loop-rewrite-summary.md` (cited evidence, not re-read — ruling already quotes the relevant finding)
- **Artifacts**: this report (`specs/184_decide_lean_skeleton_plan_completion_routing/reports/01_skeleton-follow-up-routing.md`)
- **Standards**: report-format.md, subagent-return.md

## Executive Summary

- The disposition question is already closed (ruled 2026-09-22): skeleton plans terminate through the ordinary completion-claim gate, not a ported `pr_ready` branch; only the follow-up *reporting* of `sorry_inventory[]` was lost and must be restored as a report-only mechanism (no auto-task-creation).
- This research confirms the mechanics the ruling asserts are real: `orchestrate-cycle-plan.sh`'s "no OPEN heading" fallthrough (`orchestrate-cycle-plan.sh:2582`) already routes an exhausted skeleton plan into ordinary status-derived implement dispatch, which in turn reaches `orchestrate-cycle-postflight.sh`'s `implemented)` case and `skill_gate_completion_claim` (`skill-base.sh:1243`) exactly like any other task — a skeleton plan with `phases_completed >= phases_total` already passes Case 2 today, with zero porting needed for the terminal-status path itself.
- `orchestrate-cycle-postflight.sh` currently reads `phases_completed`/`phases_total`/`artifacts`/etc. from the handoff but never reads `.skeleton` or `.sorry_inventory` — confirmed by grep (zero hits). This is the one genuine, concrete gap: a skeleton plan's strategic sorries vanish silently at completion.
- This research picks the field: **`skeleton_follow_ups`**, a dedicated append-only array on the task's `state.json` entry, shaped as the `sorry_inventory` entries themselves (not `memory_candidates`' content/category/confidence shape) — the reasoning is in Decisions below.
- Recommended hook point: inside `orchestrate-cycle-postflight.sh`'s `implemented)` case, immediately after `skill_gate_completion_claim` returns true and before/alongside the existing `skill_orchestrate_propagate_completion` call, using the `$handoff` variable already in scope at that point (no new file read needed).
- Three doc files and one test file need updates; all four are already named in the task's `file_scope`, confirming the research-to-plan handoff has no scope surprises.

## Context & Scope

This is a **mechanism-design research phase**, not a disposition-decision phase — the disposition
was ruled on 2026-09-22 (eighth-pass phase 0) and is recorded verbatim in the task description.
The open questions this phase had to resolve, per the ruling's own parenthetical ("research picks
the field"), are:

1. What field name and shape records the follow-ups on `state.json`?
2. Where exactly in `orchestrate-cycle-postflight.sh` does the detection/reporting hook go?
3. What filters/gates apply (all `sorry_inventory` entries, or only `strategic: true` ones)?
4. What exactly changes in `status-markers.md` and `handoff-schema.md`?
5. What does the new regression test fixture need to assert?

Scope is bounded to the four files in the task's `file_scope`:
`agent-system/extensions/core/scripts/orchestrate-cycle-postflight.sh`,
`agent-system/extensions/core/scripts/tests/test-orchestrate-cycle-postflight.sh`,
`agent-system/extensions/core/docs/architecture/handoff-schema.md`,
`agent-system/extensions/core/context/standards/status-markers.md`. No change to
`orchestrate-cycle-plan.sh`, `wrap-up.md`, `anti-analysis.md`, or `recovery.md` is in scope or
needed — all four already describe the handoff-writer side (`sorry_inventory` schema, strategic
test, rung (b)) correctly and unchanged by this task.

## Findings

### The terminal-status path needs no porting (confirms the ruling)

- `orchestrate-cycle-plan.sh:2500-2506` already documents, in a code comment, that the single-task
  engine's `elif last_skeleton` branch (the `pr_ready`-routing one) was *deliberately not ported*,
  and that a skeleton plan falls through to "ordinary dispatch" today.
- `orchestrate-cycle-plan.sh:2582`'s "no OPEN heading found... falls through to ORDINARY
  status-derived implement dispatch" comment is the concrete fallthrough the ruling cites.
- `skill_gate_completion_claim` (`skill-base.sh:1243-1272`) has three cases; Case 2
  (`phases_total > 0 && phases_completed >= phases_total`) is an unconditional allow with no
  skeleton-awareness at all — a skeleton plan whose last phase closes with `phases_completed ==
  phases_total` passes exactly like a non-skeleton plan. No code change is needed here.
- `status-markers.md:110-126` already documents `[PR READY]` as `task_type == "pr"`-only and
  states explicitly that a non-pr task "still terminates at `[COMPLETED]` exactly as before; it
  never passes through `[PR READY]`" — this independently corroborates the ruling's "pr_ready is
  a type=pr-only terminus" claim; no correction needed to that section.

### The follow-up-reporting gap is real and precisely located

- `grep -n "skeleton\|sorry_inventory" orchestrate-cycle-postflight.sh` returns zero hits. The
  script reads `phases_completed`, `phases_total`, `plan_markers_verified`, `artifacts[0].*` from
  the handoff (`orchestrate-cycle-postflight.sh:599-609`) but nothing else from it.
- The `handoff` variable is a **script-level** (not function-scoped) bash variable, set once at
  line 599 from `cat "$handoff_file"`, and remains in scope for the rest of the script including
  the `implemented)` case at lines 987-1023. No second file read is needed to add
  `.skeleton`/`.sorry_inventory` extraction.
- `wrap-up.md:90-98` defines the canonical `sorry_inventory` entry schema: `{file, line, statement,
  strategic, assumption, why_deferred, follow_up_task}`, and states `follow_up_task` is "REQUIRED
  (non-null) when `strategic: true`" — non-strategic entries (ordinary leaf sub-sorries) carry no
  owner and are not follow-up-reportable.
- `handoff-schema.md:276-287` currently documents both `skeleton` and `sorry_inventory` as "Read
  only by the hard engine" — accurate today, but will become stale once
  `orchestrate-cycle-postflight.sh` (a script shared, unconditionally, by both the base and hard
  engines — see its own `--hard` usage flag) starts reading `sorry_inventory` regardless of mode.
  This is harmless in base mode because base-mode handoffs never populate these fields (base mode
  never loads `wrap-up.md`'s H9 contract per that file's own header), but the doc sentence needs a
  one-line update so it does not misstate who reads the field.

### Completion-summary propagation mechanics

- `completion_summary` is a single string field on the `state.json` task entry
  (`state-management-schema.md:228`), written by `skill_propagate_completion_summary`
  (`skill-base.sh:1089-1104`) only when non-empty, sourced from `.return-meta.json`'s
  `completion_data.completion_summary` via `orchestrate-recover-outcome.sh`
  (`orchestrate-recover-outcome.sh:276`) and passed through
  `skill_orchestrate_propagate_completion`'s `precomputed_json` argument
  (`skill-base.sh:1511-1540`, called at `orchestrate-cycle-postflight.sh:1017-1018` with
  `"${recover_json:-}"`).
- There is no existing mechanism for *postflight itself* to append text to `completion_summary` —
  today it only relays what the agent wrote. Surfacing follow-ups "in the task's completion
  summary section" therefore requires augmenting the `completion_json` blob (specifically its
  `.completion_summary` field) before it reaches `skill_orchestrate_propagate_completion`, since
  that function performs the actual `state-write.sh` call.

### Append-only field precedent (`memory_candidates`)

- `memory_candidates` (`state-management-schema.md:230-247`) is the closest existing precedent for
  an append-only, agent-populated array field on the task entry: `skill_propagate_memory_candidates`
  (`skill-base.sh:1022-1042`) appends via `+=` (never overwrites), is a short, self-contained
  helper, and documents its own append-only semantics inline.
- Its *entry shape* (`content`, `category`, `source_artifact`, `confidence`,
  `suggested_keywords`) is purpose-built for prose knowledge destined for the memory vault — it
  has no field for a source file/line, a verbatim statement, or an owning follow-up task, all of
  which are exactly what a human needs to file the follow-up task via `/task` (the (iii)
  requirement). Reusing that shape would force either lossy translation (stuffing
  `{file}:{line}: {statement}` into `content`) or silently dropping fields a human would want.

### Test harness pattern

- `test-orchestrate-cycle-postflight.sh` is a sandbox-based fixture suite (`setup_sandbox`,
  `write_state`, `run_sut`, `pass`/`fail`) that copies real collaborator scripts into a synthetic
  tree and exercises the real call graph. Existing `"implemented"` fixtures
  (e.g. `orchestrate-cycle-postflight.sh` test around line 179) write a `.return-meta.json` with
  `metadata.phases_completed`/`phases_total` and a non-stale `.orchestrator-handoff.json`
  matching `dispatch_seq`. A new skeleton fixture needs the same shape plus `"skeleton": true` and
  a two-entry `"sorry_inventory"` on the handoff (not `.return-meta.json` — `sorry_inventory` is a
  handoff-side field per `wrap-up.md`/`handoff-schema.md`), with `phases_completed ==
  phases_total` so the completion-claim gate passes and the skeleton-reporting branch is actually
  reached.

### `test-handoff-reader-parity.sh` assertion removal (evidence context, not in scope)

- The task's EVIDENCE line cites assertions removed from this file covering `.skeleton`/
  `.last_skeleton` and `.sorry_inventory`/`follow_up_tasks` — these covered the now-deleted
  single-task engine's reader path specifically, not the mechanism this task restores. This file
  is not in `file_scope` and the ruling's SCOPE line names only
  `scripts/tests/test-orchestrate-cycle-postflight.sh` as the regression-test target. Restoring
  the old assertions would test a code path (the single-task engine) that no longer exists;
  leaving them removed is correct and not a gap this task should close.

## Decisions

- **Field name**: `skeleton_follow_ups` (not a reuse of `memory_candidates`'s shape). Rationale in
  Findings above — the `sorry_inventory` entry shape already carries exactly the fields a human
  needs to file a follow-up task, and `memory_candidates`'s shape is purpose-built for a different
  kind of content (reusable technique/pattern prose for the memory vault), not sorry-tracking.
- **Entry shape**: each `skeleton_follow_ups[]` entry is the `sorry_inventory` entry verbatim —
  `{file, line, statement, strategic, assumption, why_deferred, follow_up_task}` — plus two
  provenance fields the task entry doesn't otherwise carry: `recorded_cycle` (the cycle count at
  record time) and `session_id` (the dispatch session that reported it), mirroring how
  `memory_candidates` entries are appended as-is without a separate transform step.
- **Filter**: only entries with `strategic: true` are appended to `skeleton_follow_ups` and
  printed to stderr. A non-strategic `sorry_inventory` entry is an ordinary leaf sub-sorry with no
  required `follow_up_task` owner (per `wrap-up.md`) and is not follow-up-reportable; including it
  would produce noise with no actionable owner field.
- **Trigger gate**: fire only inside the `implemented)` case, only after
  `skill_gate_completion_claim` returns true (i.e., only on an actual completion, never on a
  `partial`/`blocked` outcome — consistent with `skeleton`'s own validity constraint in
  `wrap-up.md`, "`true` ONLY when `status == "implemented"`"), and only when the filtered
  strategic-entry array is non-empty. No separate `$hard_mode` check is added: `.skeleton` and
  `.sorry_inventory` default to `false`/`[]` via `jq`'s `// `, which is already harmless in base
  mode (base-mode handoffs never populate these fields), matching how `phases_completed`/
  `phases_total` are already read unconditionally regardless of mode.
- **Hook point**: `orchestrate-cycle-postflight.sh`'s existing `implemented)` case
  (lines ~987-1023), reusing the already-in-scope `$handoff` variable — no new file read.
- **Completion-summary augmentation**: build the follow-up text block from the filtered
  strategic-entry array and append it to `recover_json`'s `.completion_summary` field (via a `jq`
  transform) before passing the result as `skill_orchestrate_propagate_completion`'s
  `precomputed_json` argument, rather than modifying `skill_orchestrate_propagate_completion`
  itself (which is shared by every terminal "implemented" exit in both engines and must not
  special-case one caller's handoff shape).
- **stderr report**: print each filtered entry as its own `${notice_prefix}` line (one line per
  follow-up, not a single blob), so each is independently greppable in cycle output — e.g.
  `${notice_prefix} SKELETON FOLLOW-UP: {file}:{line} — {assumption} (owner: {follow_up_task})`.
- **No auto-task-creation**: confirmed as a hard constraint already decided by the ruling (iii);
  this research adds no mechanism that creates, drafts, or stages a `/task` invocation — the
  stderr lines and the `state.json` field are the full extent of the "report," and the user files
  tasks manually.
- **`test-handoff-reader-parity.sh` is left untouched**: its removed assertions covered dead code
  (the deleted single-task engine); restoring them is out of scope and would not test anything
  live.

## Recommendations

1. **`orchestrate-cycle-postflight.sh`**: in the `implemented)` case, after the
   `skill_gate_completion_claim` success branch is entered (around line 990), extract
   `skeleton=$(echo "$handoff" | jq -r '.skeleton // false')` and
   `follow_ups_json=$(echo "$handoff" | jq -c '[(.sorry_inventory // [])[] | select(.strategic == true)]')`.
   When `skeleton == "true"` and `follow_ups_json` is non-empty: (a) loop and `echo` one
   `${notice_prefix} SKELETON FOLLOW-UP: ...` line per entry to stderr; (b) build an augmented
   `completion_json` (append a "Skeleton follow-ups:" block, one bullet per entry, to
   `.completion_summary`) and pass that augmented JSON as `skill_orchestrate_propagate_completion`'s
   `precomputed_json` argument instead of the raw `recover_json`; (c) call a new
   `skill_propagate_skeleton_follow_ups "$task_number" "$follow_ups_json" "$session_id"` helper.
2. **`skill-base.sh`** (not in this task's `file_scope` — flag for the plan phase to confirm
   whether it needs adding to `file_scope`, since the new helper function must live somewhere
   collaborator scripts can source it; `skill-base.sh` is the existing home for
   `skill_propagate_memory_candidates` and is the natural, minimal-surprise location): add
   `skill_propagate_skeleton_follow_ups`, modeled line-for-line on
   `skill_propagate_memory_candidates` (`skill-base.sh:1022-1042`) — same `+=` append pattern,
   same `state-write.sh` routing, same self-generated `session_id` default.
3. **`handoff-schema.md`**: update the `skeleton` (line ~276) and `sorry_inventory` (line ~282)
   field docs' "Read only by the hard engine" sentences to add: "...and by
   `orchestrate-cycle-postflight.sh`'s skeleton-follow-up completion reporting (both engines;
   base-mode handoffs never populate these fields, so the read is a no-op there)."
4. **`status-markers.md`**: add a short paragraph under `[COMPLETED]` (after line ~136) stating
   that a strategic-sorry skeleton plan (hard-mode-only; see `anti-analysis.md`) terminates at
   `[COMPLETED]` through the ordinary completion-claim gate exactly like any other task — it never
   routes through `[PR READY]` — and that its `sorry_inventory[]` follow-ups are surfaced in the
   cycle's stderr report and the task's `completion_summary`/`skeleton_follow_ups` array rather
   than auto-filed as tasks.
5. **`state-management-schema.md`** (not in `file_scope` — flag for the plan phase): document the
   new `skeleton_follow_ups` field in the same style as the existing "Memory Candidates Field"
   subsection (field table, Lifecycle: Producer/Consumer/Semantics). This file is the authoritative
   schema reference the ruling explicitly names ("state-management-schema.md documents it") but
   it is absent from the task's current `file_scope` — the plan phase should add it.
6. **`test-orchestrate-cycle-postflight.sh`**: add one new acceptance case following the existing
   `setup_sandbox` / `write_state` / `run_sut` pattern: a candidate task with a non-stale,
   dispatch_seq-matching handoff carrying `"status": "implemented"`, `phases_completed ==
   phases_total`, `"skeleton": true`, and a two-entry `sorry_inventory` (one `strategic: true`
   with a non-null `follow_up_task`, one `strategic: false` with no `follow_up_task`, to assert the
   filter). Assert: (a) stderr contains exactly one `SKELETON FOLLOW-UP` line (the non-strategic
   entry is filtered out); (b) `state.json`'s task entry has a `skeleton_follow_ups` array of
   length 1 matching the strategic entry; (c) `completion_summary` contains the follow-up text;
   (d) the task still transitions to `completed` normally (the gate is unaffected).

## Risks & Mitigations

- **Risk**: augmenting `completion_json` before calling `skill_orchestrate_propagate_completion`
  could diverge from the shared function's contract if a future caller also needs to augment
  `completion_summary` for a different reason. **Mitigation**: keep the augmentation entirely
  inside `orchestrate-cycle-postflight.sh`'s own `implemented)` case (build a local modified copy
  of `recover_json`, never touch `skill_orchestrate_propagate_completion` itself) so the shared
  function's contract is unchanged for every other caller.
- **Risk**: `skill-base.sh` and `state-management-schema.md` are outside the task's declared
  `file_scope`, so an implementer following `file_scope` literally could miss them.
  **Mitigation**: flagged explicitly in Recommendations 2 and 5 above for the plan phase to carry
  forward into an updated `file_scope`.
- **Risk**: a skeleton plan whose `sorry_inventory` entries are all non-strategic (malformed
  handoff — `skeleton: true` but no strategic entry) would silently report nothing.
  **Mitigation**: this is the correct behavior per `wrap-up.md`'s own validity matrix (a skeleton
  outcome should always carry at least one strategic entry with a `follow_up_task`); an inventory
  with zero strategic entries under `skeleton: true` is itself a handoff-writer defect better
  caught by `wrap-up.md`'s own hard-mode contracts than papered over here.

## Context Extension Recommendations

- **Topic**: `/todo` archival harvest of `skeleton_follow_ups`.
- **Gap**: `memory_candidates` and `reflection` are both surfaced read-only by `/todo`'s harvest
  stage at archival time (`state-management-schema.md`'s Lifecycle sections); `skeleton_follow_ups`
  has no equivalent archival-time surfacing in this task's scope, so a task archived with unfiled
  follow-ups could lose visibility into them.
- **Recommendation**: a future task could extend `/todo`'s harvest stage to also surface
  `skeleton_follow_ups` read-only, mirroring `reflection`'s treatment — explicitly out of scope
  here since the ruling's SCOPE line does not mention archival behavior.

## Appendix

- Search queries used: `grep -rn "skeleton" orchestrate-cycle-postflight.sh orchestrate-cycle-plan.sh`;
  `grep -rln "sorry_inventory"` across `agent-system/`; `grep -n "sorry_inventory\|follow_up_task\|skeleton" handoff-schema.md`; `grep -n "memory_candidates" state-management-schema.md`.
- Key files referenced by path: `agent-system/extensions/core/scripts/orchestrate-cycle-postflight.sh`,
  `agent-system/extensions/core/scripts/orchestrate-cycle-plan.sh`,
  `agent-system/extensions/core/scripts/skill-base.sh`,
  `agent-system/extensions/core/docs/architecture/handoff-schema.md`,
  `agent-system/extensions/core/context/contracts/wrap-up.md`,
  `agent-system/extensions/core/context/standards/status-markers.md`,
  `agent-system/extensions/core/context/reference/state-management-schema.md`,
  `agent-system/extensions/core/scripts/tests/test-orchestrate-cycle-postflight.sh`.
