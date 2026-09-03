# Return-Meta Artifacts Template (Canonical Fragment)

This file is the single authoritative source for the `artifacts` array's object-shaped inline
template that dispatchable agents carry in their terminal-metadata `.return-meta.json` examples.
It exists so the template has exactly one place to edit, instead of drifting independently across
~23+ agent files.

## Generated-Copy Source, Not an `@`-Import

**This fragment is a generated-copy source, read by a human or a lint script — it is NOT
`@`-imported into agent bodies at spawn time.** The same constraint documented in
`no-task-references-bullet.md` applies here: `@`-references inside an agent body do not
auto-resolve when Claude Code spawns a subagent. An agent body carries a **literal copy** of the
template below; `lint-agent-contracts.sh` Check F keeps every copy in sync by comparing it against
this file at runtime, not against a hardcoded string baked into the lint.

## The Canonical Template

Copy this exact object shape (adapting only the illustrative `type` value and `path` to the
target agent's own artifact kind — the key set and object shape must remain byte-identical) into
the target agent's terminal-metadata `.return-meta.json` example, as the value of the `artifacts`
field:

```json
"artifacts": [
  {
    "type": "summary",
    "path": "specs/{NNN}_{SLUG}/summaries/{NN}_{slug}-summary.md",
    "summary": "One-line description of what the summary covers."
  }
]
```

Every element MUST be an **object** carrying non-empty `type`, `path`, and `summary` keys. A
bare-string array element (e.g. `"artifacts": ["specs/.../summary.md"]`) is never a valid
substitute for this shape, in any context — see `return-metadata-file.md`'s `### artifacts
(required)` section for the normative statement this fragment implements.

This exact shape is modeled on `core/agents/general-implementation-agent.md`'s worked example
(its `implemented`-status and phase-end-handoff `.return-meta.json` blocks), which is confirmed as
the reference agent to copy from.

## Classification Rule: Which Agents Must Carry the Template

An agent MUST carry this template **if and only if it writes `.return-meta.json`** — i.e. it is a
dispatchable agent (matched by `lint-agent-contracts.sh`'s `is_dispatchable_agent` detector) that
participates in the file-based metadata exchange described in `return-metadata-file.md`. This is
a decision, stated explicitly, not an omission:

**In scope**: every dispatchable agent that writes `.return-meta.json` at the end of its
execution — this covers all core and extension research, planning, and implementation agents, as
well as any specialized agent (vetting, routing, synthesis, spawn, review) that terminates by
writing the file.

**Out of scope (deliberate exclusions)**: an agent that is dispatched but never writes
`.return-meta.json` itself (for example, because it is a wrapper-only or non-terminal helper
whose output is consumed entirely by its own orchestrating skill through another channel). Any
such exclusion must be recorded explicitly at the point the classification is applied — e.g. in
the implementing plan's phase notes — rather than silently left off this fragment's rollout scope.
`core/agents/README.md` is not a dispatchable agent (no frontmatter `name:` key) and is
categorically excluded, not a case requiring per-file judgment.

## The Path-Segment Type-Inference Table

The single mapping from an artifact's path segment to its inferred `type`, implemented in code by
`scripts/lib/return-meta-artifacts-lib.sh`'s `infer_artifact_type` and consumed identically by
`validate-return-meta.sh --fix` and the `skill_read_metadata` consumer chokepoint:

| Path segment | Inferred `type` |
|--------------|------------------|
| `reports/`   | `report`         |
| `plans/`     | `plan`           |
| `summaries/` | `summary`        |

A path matching none of these segments infers no type (empty result) — the inference never
guesses. This table is prose here and code in `return-meta-artifacts-lib.sh`; the two must never
drift independently of each other.

## Placement

Insert the template into the agent's existing terminal-metadata `.return-meta.json` example(s),
adjacent to wherever the agent already documents writing the file. For an agent whose only
existing example shows `"artifacts": []` (correct for `in_progress`/early metadata), keep that
example intact and add the populated object example alongside it, so both the empty and populated
shapes are visible. Where an agent carries only a prose warning about `.artifacts[0].path` (with
no inline JSON template), keep the prose and add the template — prose alone does not substitute
for a copyable example.

## The `dispatch_seq` Sibling Field

Every agent in scope under the Classification Rule above also echoes a top-level `dispatch_seq`
field, a sibling of `artifacts` — not a member of the `artifacts` array itself. Copy the value
verbatim from this dispatch's own identity: the delegation context's `dispatch_seq` field when
present, or the dispatch file's Identity section `dispatch_seq:` line otherwise. Never invent,
increment, or recompute this value — it exists solely so a downstream identity-comparison
consumer (`orchestrate-recover-outcome.sh`) can discriminate this dispatch's own report from a
still-live or resurrected predecessor's, mirroring `.orchestrator-handoff.json`'s own
`dispatch_seq` field.

```json
{
  "status": "implemented",
  "dispatch_seq": 17,
  "artifacts": [
    {
      "type": "summary",
      "path": "specs/{NNN}_{SLUG}/summaries/{NN}_{slug}-summary.md",
      "summary": "One-line description of what the summary covers."
    }
  ]
}
```

See `context/formats/return-metadata-file.md`'s `### dispatch_seq (optional)` section for the
full normative field spec, including the graceful-degradation contract for an absent value.

## Normative Cross-Reference

This fragment records the copyable template; `.claude/context/formats/return-metadata-file.md`
(source: `agent-system/extensions/core/context/formats/return-metadata-file.md`) is the normative
schema for `.return-meta.json` as a whole, including the full field specification and the
four-layer strict-contract-plus-normalizing-chokepoint posture. Neither file is readable as the
sole authority — the schema document states the rules, this fragment holds the exact copyable
text.
