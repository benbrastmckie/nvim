# Hard-Mode Routing: Composition Model

This document describes the `--hard` routing resolution implemented in the shared
`manifest-routing-lib.sh` ladder and consumed by `command-route-agent.sh` (agent resolution) —
the sole surviving routing resolver since the routing-ladder collapse retired the parallel
skill-level resolver (now removed from the source store entirely) and its `routing`/`routing_hard` manifest
blocks. It covers the 4-step precedence against `routing_agents_hard`, the "extension overrides
core" rule, and the standard-block fallback that prevents a hard-mode miss from discarding a
declared domain agent. See `context/guides/manifest-routing-schema.md` for the full routing model
(the two surviving routing blocks plus the unrelated one-level `hard_contracts` key, core
identification, and the declared-not-derived agent-name rule); this document focuses
specifically on the `--hard` resolution path.

**Scope**: This document is the sole canonical home for the `--hard` routing-precedence rules.
CLAUDE.md's "Routing Mechanism" subsection carries only a pointer to this document (and to
`context/guides/manifest-routing-schema.md`) — the 5-step precedence list itself is maintained
here only, not duplicated there. The rest of CLAUDE.md's "Hard Mode" section (What Hard Mode
Does, When to Use, Cost Impact, Composability, Per-Invocation Only) is unrelated to this
document's scope and is maintained directly in CLAUDE.md.

---

## Overview

When a command is invoked with `--hard`, `command-route-agent.sh` receives
`effort_flag="hard"` as its 4th argument. It first resolves the standard `routing_agents` value
unconditionally (so a fallback value is already in hand), then applies a 4-step hard-mode
resolution against `routing_agents_hard` to try to override `AGENT_NAME` with the appropriate
hard-mode agent, falling back to the standard value — never to nothing — on a hard-mode miss.

---

## 4-Step Resolution Precedence

Resolution proceeds in order; the **first match wins** and short-circuits
all remaining steps.

```
Given: operation ("research"|"plan"|"implement"), task_type, effort_flag="hard"

Step 1: Search non-core extension manifests for routing_agents_hard[$op][$task_type]
        → First non-core manifest hit → AGENT_NAME = that agent; DONE

Step 2: If no hit and task_type contains ":", compute base_type (split on ":")
        Search non-core extension manifests for routing_agents_hard[$op][$base_type]
        → First non-core manifest hit → AGENT_NAME = that agent; DONE

Step 3: Search core manifest (identified by .name == "core") for routing_agents_hard[$op][$task_type]
        → Hit → AGENT_NAME = that agent; DONE

Step 4: If no hit and task_type contains ":", compound-key fallback against core
        Search core manifest for routing_agents_hard[$op][$base_type]
        → Hit → AGENT_NAME = that agent; DONE

Fallback (reaches here only if all 4 steps above missed): AGENT_NAME = the already-resolved
standard routing_agents value (via="hard-miss-standard-fallback"), never the caller's generic
hard default -- that default is reached only on a genuine total miss of BOTH blocks.
```

---

## "Extension Overrides Core" Rule

Non-core extensions (Steps 1-2) are scanned **before** the core extension
(Steps 3-4). This is deterministic regardless of glob ordering because the
core manifest is identified by `.name == "core"` and explicitly skipped during
the non-core pass (`routing_exempt: true` is also set on `core`, but is not
unique to it -- `literature` and `slidev` set it too, for their own,
independently-scoped exemption semantics; it is no longer used for core
identification).

**Consequence**: If both a non-core extension and the core manifest declare a
`routing_agents_hard` entry for the same `($op, $task_type)` pair, the non-core
extension's entry wins unconditionally.

**Example** (hypothetical override):
```
Core:    routing_agents_hard.implement.mytype = "mytype-implementation-hard-agent"
Non-core: routing_agents_hard.implement.mytype = "myext-implementation-hard-agent"
Result:  AGENT_NAME = "myext-implementation-hard-agent"
```

---

## Standard-Block Fallback (Never a Bare Undeployed Guess)

Unlike the now-retired skill-level resolver's `-hard` append-fallback step (which speculatively
guessed at an undeployed skill name and gated the guess on `SKILL.md` existence),
`command-route-agent.sh`'s hard-mode miss path never guesses a name: it falls back to the
ALREADY-RESOLVED standard `routing_agents` value for that same `(op, task_type)` — a value that,
by Check B / `verify-deploy` gate 7, is already guaranteed to name an existing agent file. There
is no name-guessing step and so no existence gate is needed on this path. The caller's generic
hard default is reached only if BOTH `routing_agents_hard` and `routing_agents` miss entirely for
the given task_type (see `test-routing-resolution.sh`'s Assert 3 semantic cases for the three
rungs this produces: hard-hit, standard-fallback, and total-miss).

---

## Deployed Hard Agents (current inventory)

Core's own four standalone lifecycle-stage `-hard` skills (the research/plan/implement stage
skills plus the standalone hard-mode orchestrator) were deleted: `--hard` behavior for
`general`/`meta`/`markdown` task types is now a `hard_mode` flag inside the single
`skill-orchestrate` engine (`orchestrate-build-dispatch.sh`'s Stage 3.5 hard-mode contract injection, `orchestrate-cycle-plan.sh`'s H1 per-phase dispatch selection), not a separate skill file or a separate manifest routing table. Core's
own `routing_agents_hard` manifest block was removed along with the skills.

Extensions that still declare their own domain-specific `-hard` agents remain reachable via
manifest routing exactly as before -- transitionally; see the `hard_contracts` successor note
below:

| Agent | Reachable via |
|-------|---------------|
| `cslib-research-hard-agent` | CSLib extension manifest `routing_agents_hard` |
| `cslib-implementation-hard-agent` | CSLib extension manifest `routing_agents_hard` |
| `lean-research-hard-agent` | Lean extension manifest `routing_agents_hard` |
| `lean-implementation-hard-agent` | Lean extension manifest `routing_agents_hard` |

The four hard-mode SKILL.md files these agents are documented alongside
(`skill-cslib-research-hard`, `skill-cslib-implementation-hard`, `skill-lean-research-hard`,
`skill-lean-implementation-hard`) are themselves no longer routing-reachable by any command --
the skill-level `routing_hard` block they depended on was retired. Their provenance lines were
corrected to state this; the skills and agents are untouched otherwise.

---

## Orchestrate Hard Mode: One Engine, Effort-Gated

`skill-orchestrate` (invoked by `/orchestrate --hard`) resolves AGENT names via
`command-route-agent.sh` — the shared `manifest-routing-lib.sh` ladder, called with
`effort_flag="hard"` against each manifest's `routing_agents_hard` block instead of
`routing_agents`. There is no longer a second, standalone engine file: base mode and hard mode
share `orchestrate-cycle-plan.sh`'s `resolve_agent()` resolution calls and diverge only on the
`$hard_mode` variable (derived once per invocation from `effort_flag == "hard"`) — see
`docs/architecture/orchestrate-state-machine.md` for the full mapping of which script now owns
each hard-mode technique (H1/H4/H5/H6/etc.). See `context/guides/manifest-routing-schema.md` for
the full routing model.

---

## `routing_agents_hard` Is Transitional: `hard_contracts` Is Its Successor

`routing_agents_hard` remains live today for exactly two extensions (`cslib`, `lean`) and is
itself slated for outright removal once a separate, not-yet-dispatched follow-on migrates them
onto `hard_contracts` — the mechanism `--hard` dispatch prep now uses for every OTHER task type's
hard-mode behavior (injecting behavioral-contract files into the dispatch prompt, per the
`hard_contracts` block documented in `context/guides/manifest-routing-schema.md`). Until that
follow-on lands, `verify-deploy.sh` gate 16 keeps emitting a non-blocking warning for `cslib` and
`lean` as a removal-is-coming nudge. This is NOT a migration of `routing_agents_hard`'s VALUES
onto `hard_contracts` — the two mechanisms resolve fundamentally different things (an agent name
vs. a list of contract file paths) — it is a replacement of the mechanism cslib/lean's hard-mode
behavior is expressed through.

---

## Related Files

- `.claude/scripts/lib/manifest-routing-lib.sh` — Shared ladder implementation
- `.claude/scripts/command-route-agent.sh` — Agent resolution (called from
  orchestrate-cycle-plan.sh's resolve_agent(), both effort modes) — the sole surviving resolver
- `.claude/extensions/cslib/manifest.json` — CSLib `routing_agents_hard` entries (transitional)
- `.claude/extensions/lean/manifest.json` — Lean `routing_agents_hard` entries (transitional)
- `context/guides/manifest-routing-schema.md` — Full routing model (the two surviving routing
  blocks plus the one-level `hard_contracts` block this document otherwise does not cover — a
  different mechanism, contract-text injection rather than agent resolution)
