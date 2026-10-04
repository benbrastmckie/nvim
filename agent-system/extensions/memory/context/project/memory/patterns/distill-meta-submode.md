# Sub-Mode: meta

This file is the COMPLETE and ONLY specification for skill-distill's `--meta` sub-mode execution. It MUST be followed exactly -- there is no fuller version of this content anywhere else. The `Sub-Mode: meta` section of `skill-distill/SKILL.md` was extracted here per `context/patterns/mode-gated-section-loading.md`; the pointer at that section's former location in `SKILL.md` sends an agent here whenever `--meta` is dispatched.

Cross-repo agent-system improvement proposals. `--meta` inherits, in substance unchanged, the
current `dream` section's "Improvement Proposals" discovery, presentation, and confirmation
logic -- this content is relocated from `dream` (Phase 10 removes the now-duplicated copy from
`dream` once this section fully contains it). **New in this sub-mode**: explicit cross-repo
target resolution via the existing `$GLOBAL_ROOT` mechanism, and delegation of task creation to
`meta-builder-agent` rather than reimplementing the `/task` primitive inline. Follows the Shared
Sub-Mode Skeleton in `skill-distill/SKILL.md`; deltas below.

## Edge Case Checks

```
1. Resolve target_root (see Target Resolution below)
2. Run validate-on-read against the resolved repo's event/reflection sources
3. If zero deviation/blocker/reflection signal is available at target_root:
   Display: "No agent-system improvement signal found in this repo's specs/events.jsonl or
   reflections. Nothing to propose this run."
   Return early.
```

## Target Resolution (Consumes, Does Not Invent)

`--meta` consumes the existing global-root mechanism verbatim. **It does not invent a parallel
resolver.**

```bash
GLOBAL_ROOT="${CLAUDE_AGENT_GLOBAL_ROOT:-$HOME/.config/nvim}"
target_root="$GLOBAL_ROOT"
# --local opts out of the cross-repo default, scoping to the invoking repo instead:
if [ -n "${DISTILL_META_LOCAL:-}" ] || [[ " $* " == *" --local "* ]]; then
  target_root="$(pwd)"
fi
cd "$target_root" && bash .claude/scripts/events-query.sh --format summary-counts
```

Running `--meta` from a session already inside `$GLOBAL_ROOT` is a genuine no-op for this step
(`target_root` resolves to the same directory the session is already in), not a special branch
requiring its own handling.

**Single-repo signal limitation** (stated here, in this flag's own description, not only in
commentary): `events.jsonl` is a per-repo file. `--meta` invoked against `$GLOBAL_ROOT` sees only
`$GLOBAL_ROOT`'s own event store, not aggregated signal from every other repo this agent system
runs in. `events-query.sh`'s `--repo` filter operates within a single file and does **not** close
this gap. Cross-repo aggregation is an explicit out-of-scope follow-up (see
`telemetry-guardrails.md`'s Cross-Repo Signal Limitation).

## Candidate Identification: Discovery

Unchanged in substance from the current `dream` section's discovery logic. A proposal candidate
is surfaced when either:
- A recurring (three-strikes, per the `--revise` Classification step in
  `distill-revise-submode.md`) deviation/blocker
  event points at a named skill, hook, rule, or lifecycle stage/checkpoint, or
- A recurring `what_was_hard` / `what_was_missed` phrase appears across reflection events for the
  same or related task types (producer-status note: the `reflection` event type has no live
  producer any more -- see `context/formats/events-format.md` -- so this signal is limited to
  historical rows written before that retirement).

**Extension targeting**: `meta-builder-agent` is expected to decide which of this system's
extension directories (`agent-system/extensions/{core,cslib,email,epidemiology,filetypes,formal,
founder,latex,lean,literature,memory,nix,nvim,present,python,slidev,typst,web,z3}/`) a proposal
should contribute to. **Do not write new detection logic here.**
`meta-builder-agent.md`'s own documented "Known limitation" states its affected-area heuristic
"has no reliable signal to distinguish core scope from an extension's own source directory ...
without parsing extension manifests, so extension-scoped tasks require human correction rather
than a guess" -- it defaults to `agent-system/extensions/core/` and relies on the delegation
contract's own `AskUserQuestion` selection/modification step (below) for a human to correct
extension-scoped proposals. `--meta` inherits this exact limitation rather than working around
it; a future improvement to `meta-builder-agent`'s own detection benefits `--meta` automatically
with no change needed here.

## Dry-Run

When `--dry-run` is active, display the full candidate list (summary, evidence citations, and the
`meta-builder-agent`-resolved affected area where available, or "core (default -- verify manually)"
where the known limitation above applies) and perform **zero task creation**:

```
[DRY RUN] Improvement proposal candidates ({count}):
  - {candidate.summary} (evidence: {event_id_1}, {event_id_2}, {event_id_3}; affected area:
    {affected_area or "core (default -- verify manually)"})
  - ...

No tasks created.
```

## Interactive Selection (MANDATORY STOP)

**Presentation**: `AskUserQuestion` `multiSelect`, one row per candidate:

```json
{
  "question": "meta surfaced {N} recurring agent-system improvement candidates at {target_root}. What should happen with each?",
  "header": "Improvement Proposals",
  "multiSelect": true,
  "options": [
    {
      "label": "{candidate.summary}",
      "description": "Evidence: {event_id_1} ({message_1}), {event_id_2} ({message_2}), {event_id_3} ({message_3}) -- recurring at checkpoint '{checkpoint}'"
    }
  ]
}
```

For each selected candidate, a second `AskUserQuestion` (or a combined per-row selector) offers:
- **Create as task** -- delegated to `meta-builder-agent` (see Execution below)
- **Note in report only** -- recorded in the meta-log but no task created
- **Skip** -- discarded entirely

**MANDATORY STOP (Shared Sub-Mode Skeleton, Interactive Selection step). Do NOT delegate task
creation for any candidate without explicit user selection at this step.** This is the
evaluator-outside-the-loop rule from `telemetry-guardrails.md`.

**Confirmation gate**: before any task is actually created, show the full list of confirmed
"Create as task" candidates and require an explicit "Yes, create tasks" confirmation (Multi-Task
Creation Standard Component 7) -- mirroring every other multi-task creator in this codebase,
including the user's opportunity to select and modify the proposed tasks before anything is
created.

## Execution: Delegation Contract to `meta-builder-agent`

**Task creation delegates to `meta-builder-agent` via the Agent tool. Do not reimplement the
`/task` primitive inline.**

**What is passed**:
```json
{
  "proposal_set": [
    {
      "summary": "{candidate.summary}",
      "evidence_event_ids": ["evt_..."],
      "checkpoint": "{checkpoint}",
      "affected_area_hint": "{meta-builder-agent-resolved area, or null}"
    }
  ],
  "target_root": "{resolved target_root}",
  "orchestrator_mode": false
}
```

**What comes back**: one created (or user-modified/declined) `task_type: "meta"` task entry per
confirmed proposal, each with its own task number, `file_scope` (seeded by `meta-builder-agent`
from the paths the triggering events implicate), and TODO.md/state.json entries -- all via
`meta-builder-agent`'s own existing Stage 0-N pipeline (interactive review, component selection,
multi-task creation standard compliance), not reinvented here.

**What `--meta` does with it**: records the returned task numbers in the meta-log (below) and
reports them to the user; performs no further mutation of `specs/state.json` or `TODO.md` itself
-- `meta-builder-agent` owns that write.

**Doc-edit-proposal rule**: a proposal whose remedy is "edit file X's prose" (rather than create a
new task) is a **report-only finding**. `--meta` MUST NOT edit any file itself. Recommending a doc
edit is always surfaced as a finding for the user to act on, never applied automatically.

**Cross-repo invocation discipline**: any `events-query.sh` (or other memory/event script) call
this sub-mode makes uses the mandatory chained relative form --
`cd "$target_root" && bash .claude/scripts/{name}.sh ...` in a single Bash tool call. Absolute-path
invocation is prohibited; a `cd` from an earlier, separate tool call must never be assumed to
persist. See `telemetry-guardrails.md`'s cross-repo invocation discipline -- not restated further
here.

## Batch Index Regeneration

Not applicable to `--meta` in the vault-index sense (this sub-mode does not mutate
`.memory/10-Memories/*.md` or `memory-index.json`) -- its "batch" write is the set of
`meta-builder-agent`-created tasks, which regenerate their own `TODO.md`/`state.json` via
`meta-builder-agent`'s existing pipeline, not via the JSON Index Maintenance procedure this step
otherwise refers to.

## Meta Log Schema

Operations are logged to `.memory/meta-log.json`, mirroring the shape of
`.memory/distill-log.json`:

```json
{
  "version": "1.0.0",
  "operations": [
    {
      "id": "meta_{timestamp}",
      "timestamp": "ISO8601",
      "type": "meta",
      "session_id": "sess_...",
      "target_root": "/home/user/.config/nvim",
      "proposals": {
        "surfaced": 0,
        "created_as_task": 0,
        "noted_only": 0,
        "skipped": 0,
        "task_numbers_created": []
      },
      "notes": ""
    }
  ],
  "summary": {
    "total_meta_runs": 0,
    "total_proposals_created": 0,
    "last_operation": null
  }
}
```

