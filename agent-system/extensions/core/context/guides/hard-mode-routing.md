# Hard-Mode Routing: Composition Model

This document describes the `--hard` routing resolution implemented in the shared
`manifest-routing-lib.sh` ladder and consumed by `command-route-skill.sh` (skill resolution) and
`command-route-agent.sh` (agent resolution). It covers the 5-step precedence, the
"extension overrides core" rule, and the safety gate that prevents resolution to undeployed
agents. See `context/guides/manifest-routing-schema.md` for the full routing model (all four
manifest blocks, core identification, and the declared-not-derived agent-name rule); this
document focuses specifically on the `--hard` resolution path.

**Scope**: This document is the sole canonical home for the `--hard` routing-precedence rules.
CLAUDE.md's "Routing Mechanism" subsection carries only a pointer to this document (and to
`context/guides/manifest-routing-schema.md`) — the 5-step precedence list itself is maintained
here only, not duplicated there. The rest of CLAUDE.md's "Hard Mode" section (What Hard Mode
Does, When to Use, Cost Impact, Composability, Per-Invocation Only) is unrelated to this
document's scope and is maintained directly in CLAUDE.md.

---

## Overview

When a command is invoked with `--hard`, `command-route-skill.sh` receives
`effort_flag="hard"` as its 4th argument. After standard routing resolves
`SKILL_NAME` (Steps 1-3), the script applies a 5-step hard-mode resolution
to override `SKILL_NAME` with the appropriate hard-mode skill.

---

## 5-Step Resolution Precedence

Resolution proceeds in order; the **first match wins** and short-circuits
all remaining steps.

```
Given: operation ("research"|"plan"|"implement"), task_type, effort_flag="hard"

Step 4a: Search non-core extension manifests for routing_hard[$op][$task_type]
         → First non-core manifest hit → SKILL_NAME = that skill; DONE

Step 4b: If no hit and task_type contains ":", compute base_type (split on ":")
         Search non-core extension manifests for routing_hard[$op][$base_type]
         → First non-core manifest hit → SKILL_NAME = that skill; DONE

Step 4c: Search core manifest (identified by .name == "core") for routing_hard[$op][$task_type]
         → Hit → SKILL_NAME = that skill; DONE

Step 4d: If no hit and task_type contains ":", compound-key fallback against core
         Search core manifest for routing_hard[$op][$base_type]
         → Hit → SKILL_NAME = that skill; DONE

Step 4e: -hard append fallback (only reaches here if all manifest lookups failed)
         candidate = "${SKILL_NAME}-hard"
         if .claude/skills/${candidate}/SKILL.md exists:
           SKILL_NAME = candidate; DONE
         else:
           echo "[route] No hard variant for ${SKILL_NAME}; using standard skill" >&2
           SKILL_NAME unchanged (safe default = standard skill); DONE
```

---

## "Extension Overrides Core" Rule

Non-core extensions (Steps 4a-4b) are scanned **before** the core extension
(Steps 4c-4d). This is deterministic regardless of glob ordering because the
core manifest is identified by `.name == "core"` and explicitly skipped during
the non-core pass (`routing_exempt: true` is also set on `core`, but is not
unique to it -- `literature` and `slidev` set it too, for their own,
independently-scoped exemption semantics; it is no longer used for core
identification).

**Consequence**: If both a non-core extension and the core manifest declare a
`routing_hard` entry for the same `($op, $task_type)` pair, the non-core
extension's entry wins unconditionally.

**Example** (hypothetical override):
```
Core:    routing_hard.implement.mytype = "skill-mytype-implementation-hard"
Non-core: routing_hard.implement.mytype = "skill-myext-implementation-hard"
Result:  SKILL_NAME = "skill-myext-implementation-hard"
```

---

## SKILL.md Existence Safety Gate (Step 4e Only)

The `-hard` append fallback in Step 4e is the **only** step that gates on
`SKILL.md` existence. Steps 4a-4d trust that manifest-declared `routing_hard`
entries point to deployed skills (the manifest author is responsible).

Step 4e exists to handle task types where no manifest declares a `routing_hard`
entry but a hard variant of the standard skill happens to be deployed on disk.
The gate prevents silent routing to an undeployed agent in this fallback path.

```bash
# Step 4e safety gate (in command-route-skill.sh)
if [ -f ".claude/skills/${_candidate_hard}/SKILL.md" ]; then
  SKILL_NAME="$_candidate_hard"
else
  echo "[route] No hard variant for ${SKILL_NAME}; using standard skill" >&2
  # SKILL_NAME unchanged — falls back to the standard skill
fi
```

---

## Deployed Hard Skills (current inventory)

Core's own four standalone lifecycle-stage `-hard` skills (the research/plan/implement stage
skills plus the standalone hard-mode orchestrator) were deleted: `--hard` behavior for
`general`/`meta`/`markdown` task types is now a `hard_mode` flag inside the single
`skill-orchestrate` engine (`orchestrate-build-dispatch.sh`'s Stage 3.5 hard-mode contract injection, `orchestrate-cycle-plan.sh`'s H1 per-phase dispatch selection), not a separate skill file or a separate manifest routing table. Core's
`routing_hard`/`routing_agents_hard` manifest blocks were removed along with the skills.

Extensions that still declare their own domain-specific `-hard` skills remain reachable via
manifest routing exactly as before:

| Skill | Reachable via |
|-------|---------------|
| `skill-cslib-research-hard` | CSLib extension manifest routing_hard |
| `skill-cslib-implementation-hard` | CSLib extension manifest routing_hard |
| `skill-lean-research-hard` | Lean extension manifest routing_hard |
| `skill-lean-implementation-hard` | Lean extension manifest routing_hard |

---

## Orchestrate Hard Mode: One Engine, Effort-Gated

`skill-orchestrate` (invoked by `/orchestrate --hard`) resolves AGENT names via
`command-route-agent.sh` — the same shared `manifest-routing-lib.sh` ladder
`command-route-skill.sh` uses, called with `effort_flag="hard"` against each manifest's
`routing_agents_hard` block instead of `routing_agents`. There is no longer a second, standalone
engine file: base mode and hard mode share `orchestrate-cycle-plan.sh`'s `resolve_agent()` resolution calls and diverge only on the `$hard_mode` variable (derived once per invocation from `effort_flag == "hard"`) — see `docs/architecture/orchestrate-state-machine.md` for the full mapping of which script now owns each hard-mode technique (H1/H4/H5/H6/etc.). See
`context/guides/manifest-routing-schema.md` for the full routing model.

---

## Adding routing_hard Entries

To route a new task type to a hard skill, add a `routing_hard` block to the
relevant extension's `manifest.json`:

```json
{
  "routing_hard": {
    "research": {
      "mytype": "skill-mytype-research-hard"
    },
    "plan": {
      "mytype": "skill-mytype-planning-hard"
    },
    "implement": {
      "mytype": "skill-mytype-implementation-hard"
    }
  }
}
```

Ensure the declared skill directory and `SKILL.md` exist before adding the
entry. Undeclared-but-deployed skills are automatically reachable via Step 4e.

---

## Related Files

- `.claude/scripts/lib/manifest-routing-lib.sh` — Shared ladder implementation
- `.claude/scripts/command-route-skill.sh` — Skill resolution (research.md/plan.md/implement.md)
- `.claude/scripts/command-route-agent.sh` — Agent resolution (called from
  orchestrate-cycle-plan.sh's resolve_agent(), both effort modes)
- `.claude/extensions/core/manifest.json` — Core routing_hard / routing_agents_hard entries
- `.claude/extensions/cslib/manifest.json` — CSLib routing_hard / routing_agents_hard entries
- `.claude/extensions/lean/manifest.json` — Lean routing_hard / routing_agents_hard entries
- `context/guides/manifest-routing-schema.md` — Full routing model (all five manifest blocks,
  including the one-level `hard_contracts` block this document does not cover — a different
  mechanism, contract-text injection rather than skill/agent resolution)
