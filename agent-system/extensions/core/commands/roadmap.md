---
description: Maintain the roadmap_batches/roadmap_notes entries specs/ROADMAP.md renders from
allowed-tools: Skill
argument-hint: [instruction]
---

# /roadmap Command

Maintain the `roadmap_batches` / `roadmap_notes` entries in `specs/state.json` that
`specs/ROADMAP.md`'s `## Next` and `## Open work` sections render wholly from. The judgment --
which batches exist, in what order, each batch's description and rationale, and which
dependency edges are missing -- lives in `roadmap-agent`; the rendering itself is mechanical
(`scripts/roadmap-integration.sh --regenerate`) and never makes a judgment call.

## Arguments

- `$1...` - Optional free-form instruction (quoted if it contains spaces).

## Syntax

```
/roadmap [instruction]
```

- **No argument**: perform a full maintenance pass over every open, non-terminal task -- clear
  stale batch descriptions/rationale, revise priorities (array order), revise batch membership,
  and propose any missing dependency edges the live dependency graph reveals.
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

`skill-roadmap` dispatches `roadmap-agent` for the actual decision-making (batch membership,
descriptions, rationale, and edges), then verifies the render and commits
`specs/state.json`/`specs/ROADMAP.md` as its own postflight. See `skills/skill-roadmap/SKILL.md`
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
