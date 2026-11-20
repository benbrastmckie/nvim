---
description: Maintain the milestone entries specs/ROADMAP.md is generated from
allowed-tools: Skill
argument-hint: [instruction]
---

# /roadmap Command

Maintain the `primary_goals` / `roadmap_milestones` / `roadmap_context` entries in
`specs/state.json` that `specs/ROADMAP.md` is generated from. The file has no hand-authored
section; it is rendered in three parts, in this order:

1. A brief intro: the primary goals, a status table linking to each milestone section, and a
   link to the last section.
2. One section per milestone, in order -- a collaboration dashboard: what the milestone aims to
   achieve, its progress, its git review/approval state, its gate, and its batches, each with
   what it aims to achieve, its `/orchestrate` line and its members' statuses.
3. Rules, conventions and repo context, last, followed by the open tasks that sit in no batch.

The judgment -- which milestones exist and in what order, which batches sit under which, each
batch's description, and which dependency edges are missing -- lives in `roadmap-agent`; the
rendering itself is mechanical (`scripts/roadmap-integration.sh --regenerate`) and never makes a
judgment call.

A repository whose roadmap file is still hand-authored is offered a one-time migration
(`scripts/migrate-roadmap-to-milestones.sh`) before anything else: it moves the file's content
into state and a retained-prose file, proves nothing was lost, and only then writes.

## Arguments

- `$1...` - Optional free-form instruction (quoted if it contains spaces).

## Syntax

```
/roadmap [instruction]
```

- **No argument**: perform a full maintenance pass over every milestone and every open,
  non-terminal task -- revise priorities (array order), milestone progress, batch membership and
  descriptions, and propose any missing dependency edges the live dependency graph reveals.
- **A quoted instruction**: scope that same pass to the stated focus, e.g.:
  ```
  /roadmap "focus the next batch on the lean extension"
  ```

## Execution

Invoke the Skill tool:
```
skill: "skill-roadmap"
args: "{instruction}"
```

`skill-roadmap` dispatches `roadmap-agent` for the actual decision-making (milestones, batch
membership, descriptions, and edges), then verifies the render and commits `specs/state.json`
and the roadmap file as its own postflight. See `skills/skill-roadmap/SKILL.md`
and `agents/roadmap-agent.md` for the full contract.

## Output

Report the agent's own summary of what changed and why, followed by the skill's postflight
result (whether `validate-state.sh` was clean, whether the render was confirmed fresh, and
whether a commit landed or was skipped because nothing changed).

## Examples

### Full maintenance pass
```
/roadmap
```

### Scoped to a stated focus
```
/roadmap "focus the next batch on the lean extension"
```
