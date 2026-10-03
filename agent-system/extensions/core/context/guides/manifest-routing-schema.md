# Manifest Routing Schema

This document is the authoritative description of the consolidated routing model: the two
surviving routing blocks (`routing_agents`, `routing_agents_hard`) plus one unrelated one-level
key (`hard_contracts`), the single five-step first-match-wins ladder every routing consumer
shares, core-manifest identification, `routing_exempt`'s narrowed meaning, and the rule that
agent names are always declared data, never derived strings.

**Collapsed model (post routing-ladder-collapse)**: a prior version of this document described
FOUR two-level routing blocks (`routing`, `routing_hard`, `routing_agents`, `routing_agents_hard`)
resolved by two parallel resolvers, one per layer (a skill-level resolver, `command-route-skill.sh`,
and an agent-level resolver, `command-route-agent.sh`). The skill-level layer existed only to
serve the now-deleted `/research`, `/plan`, `/implement` commands; once those commands were
deleted and `/orchestrate` became the sole dispatch path (dispatching AGENTS directly), the
skill-level blocks and their resolver had no remaining caller and were retired outright, not
migrated. `routing`/`routing_hard` are gone from every manifest; `command-route-skill.sh` no
longer exists. Only `routing_agents`/`routing_agents_hard` survive, both read exclusively by
`command-route-agent.sh`.

**Scope**: This document covers the manifest-level routing schema. For the `--hard`-specific
resolution path and its historical divergence (now eliminated), see
`context/guides/hard-mode-routing.md`. For the CLAUDE.md-level routing summary consumed by
agents at dispatch time, see the "Routing Mechanism" section of the generated CLAUDE.md (sourced
from `merge-sources/claudemd.md`).

---

## The Two Routing Blocks (Plus One Unrelated Key)

Every extension manifest may declare up to two **two-level** routing blocks, both sharing the
same `{ op: { task_type: value } }` shape (`op` is `"research"`, `"plan"`, or `"implement"`, plus
occasionally an extension-specific op like `present`'s `"critique"`), plus one **one-level**
key, `hard_contracts`, with a genuinely different shape and no relation to routing at all (see
its own subsection below). This is deliberately a two-block-plus-one-unrelated-key model, not a
three-row routing table — do not read the table below as "three kinds of routing."

| Block | Value type | Consumed by |
|-------|-----------|-------------|
| `routing_agents` | agent name, no `.md` suffix (e.g. `"epi-research-agent"`) | `command-route-agent.sh` (standard mode) |
| `routing_agents_hard` | agent name (e.g. `"lean-research-hard-agent"`) | `command-route-agent.sh` (`--hard` mode) |
| `hard_contracts` | array of contract paths/`replace:` entries (see below) | `orchestrate-build-dispatch.sh`'s Stage 3.5 Dispatch Prep, via `routing_lookup_flat()` |

`routing_agents`/`routing_agents_hard` resolve which **agent** `/orchestrate` and
`/orchestrate --hard` dispatch directly. `hard_contracts` is unrelated to this pair — it does not
resolve an agent name, it resolves the list of behavioral-contract files injected into a
`--hard` dispatch's prompt.

**Completeness rule (research-anchored, re-scoped by the routing-ladder collapse)**: every
task_type key present under `routing_agents.research` MUST have a counterpart key under
`routing_agents.plan` and `routing_agents.implement` on the same manifest.
`lint-routing-wiring.sh` Check A enforces this as a hard FAIL, not a silent gap — this is the
mechanical backstop against the defect class that let a per-op gap go undetected. Keys present
in `plan`/`implement` but absent from `research` (including an extension-specific op's own keys,
e.g. `present`'s bare `slides` key) are REPORTed, never failed — the rule is deliberately
one-directional. Separately, `lint-routing-wiring.sh` Check C enforces `routing_agents_hard`'s
own internal completeness: every task_type declared under any `routing_agents_hard.{op}` MUST
have a same-op counterpart key under `routing_agents.{op}` (a hard-mode entry for a task_type
standard mode cannot route is the gap this catches). Plan parity is NOT required in
`routing_agents_hard` — `cslib` and `lean` legitimately declare `research` + `implement` only.
`hard_contracts` has no counterpart-key rule; it is independently optional.

---

## The `hard_contracts` Block (One-Level Shape)

Unlike the four blocks above, `hard_contracts` is a **one-level** map:
`{ task_type: [ path_or_directive, ... ] }` — no intervening `op` key. A `--hard` dispatch's
per-phase contract list already varies by `phase` (`research`/`plan`/`implement`), not by
`task_type`, inside `orchestrate-build-dispatch.sh`'s own Stage 3.5 logic, so the manifest key only
needs to vary by `task_type`; forcing a fabricated `op` level onto this block to reuse
`routing_lookup()` would misrepresent its shape. It resolves through a dedicated sibling
function, `routing_lookup_flat(block, task_type)`, in `scripts/lib/manifest-routing-lib.sh` —
never through `routing_lookup()` — sharing the same 4-step non-core/core x exact/compound-base
precedence (Steps 1-4 of the Five-Step Ladder above; a one-level block has no Step 5 "no match"
distinction beyond the shared empty-output miss).

Each array entry is either:
- **A plain additive path** (e.g. `"extra-contract.md"`) — appended to the phase's fixed core
  contract list, after all core entries.
- **A `replace:{core-basename}:{override-path}` directive** — substitutes the named core-list
  entry (matched by exact basename, e.g. `replace:anti-analysis.md:my-anti-analysis.md`)
  in place, preserving its position in the list rather than appending.

Example:
```json
{
  "hard_contracts": {
    "mytype": [
      "replace:anti-analysis.md:mytype-anti-analysis.md",
      "mytype-extra-contract.md"
    ]
  }
}
```

**Current status**: no extension declares this block today — the mechanism is additive and
stays unexercised by real data on day one. Its sole consumer is
`orchestrate-build-dispatch.sh`'s Stage 3.5 Dispatch Prep ("Hard-mode contract injection" subsection),
which builds the final `hard_contracts_block` prompt-injection string from the resolved list.

---

## The Single Five-Step Ladder

Both routing blocks resolve through ONE ladder, implemented once in
`scripts/lib/manifest-routing-lib.sh`'s `routing_lookup()` function:

```
Step 1: non-core extension manifest, EXACT task_type match      -> first hit wins
Step 2: non-core extension manifest, COMPOUND-BASE match         -> first hit wins
        (only tried if task_type contains ":", e.g. "founder:deck" -> base "founder")
Step 3: core extension manifest, EXACT task_type match
Step 4: core extension manifest, COMPOUND-BASE match
Step 5: no match -> empty (caller substitutes its own default)
```

"First match wins" and "non-core scanned before core" are the SAME rule applied identically by
every consumer: `command-route-agent.sh` and `skill-orchestrate` (both effort modes share this
one engine today). Before the standalone hard-mode orchestrator was merged into
`skill-orchestrate` and then deleted, it used a different, undocumented rule (last-match-wins,
no core exclusion) — see `context/guides/hard-mode-routing.md` for that history.

Only Step 5's emptiness is a true "miss" — a caller's own default (e.g. `general-research-agent`)
is substituted OUTSIDE the ladder, by the caller, never inside `routing_lookup()` itself.
`command-route-agent.sh`'s own hard-mode composition (Steps 1-4 against `routing_agents_hard`,
falling back to the already-resolved standard `routing_agents` value, falling back again to the
caller's default) is a three-rung fallback built ON TOP of this one ladder, not a second ladder —
see `context/guides/hard-mode-routing.md` for that composition's detail. There is no `-hard`
append-fallback step here: that mechanism belonged solely to the now-deleted skill-level
resolver (`command-route-skill.sh`), which derived a `-hard`-suffixed skill name by string
convention. Agent names carry no such suffix convention, so `command-route-agent.sh` never had
an equivalent step to retire.

---

## Core-Manifest Identification

The core manifest is identified by `routing_core_manifest()`: the manifest whose `.name == "core"`.
This is the ONE place core identity is determined; every ladder step calls it (directly, or via
`routing_lookup()`'s own internal core pass).

**Why not `routing_exempt: true`?** Before this task, `routing_exempt: true` was used for core
identification — but it is not unique to `core`: `literature` and `slidev` also set it, for
their own, unrelated exemption semantics (see below). A loop identifying "the core manifest" by
`routing_exempt: true` resolved to whichever of the three sorted first in glob order (`core`,
alphabetically) — correct by coincidence, not by contract. `.name == "core"` is unambiguous.

**`routing_exempt`'s narrowed meaning**: the field is retained, but its ONLY remaining consumer
is `check-extension-docs.sh`'s doc-lint, which skips routing-consistency checks for manifests
that set it (`core`, `literature`, `slidev` — none of which participate in ordinary extension
routing). It no longer has any role in core identification.

---

## `.task_type` (singular) vs. `.routing_agents.{op}` keys (aliases)

Every manifest carries a singular top-level `.task_type` string (e.g. epidemiology's is `"epi"`),
but its `.routing_agents.{op}` blocks may declare SEVERAL alias keys resolving to the same
extension — epidemiology declares `epi`, `epi:study`, AND `epidemiology`, all routing to
`skill-epi-research` at the command layer and to the same research agent at the dispatch layer.
The singular field is insufficient by itself for directory/extension resolution;
`routing_lookup()` itself scans the `.routing_agents.{op}` keys (exact or compound-base match)
across every manifest, so no separate manifest-finding helper is needed — the resolution IS the
lookup.

**Directory-resolution-via-routing-keys convention**: before the original routing consolidation,
`skill-orchestrate` (base mode) resolved an extension's directory by assuming
`directory_name == task_type` (`.claude/extensions/${TASK_TYPE}/manifest.json`) — which silently
failed for `epi` (the extension directory is `epidemiology`, not `epi`) and only worked for
`neovim`/`lean4` because a hardcoded `case` statement masked the bug. The ladder replaces
directory-name guessing entirely: it finds the right manifest by what it DECLARES, not by what
its directory happens to be named. (A former standalone helper, `routing_manifest_for_task_type()`,
performed this same lookup against the now-deleted `.routing.{op}` blocks for callers that needed
only the manifest PATH rather than a resolved value; it had no live caller by the time the
routing-ladder collapse landed and was removed outright, not retargeted.)

---

## Agent Names Are Declared, Never Derived

Before this task, `skill-orchestrate` and its now-merged-and-deleted standalone hard-mode
predecessor derived agent names from skill names via string surgery:
`echo "$skill_name" | sed 's/^skill-//' | sed 's/$/-agent/'`. This is wrong whenever the pattern
doesn't hold:

| `task_type` | Routed skill | sed-derived (wrong) | Real agent |
|---|---|---|---|
| `memory` | `skill-learn` | `learn-agent` | *(none — direct-execution; declared explicitly as `general-research-agent`/`general-implementation-agent`)* |
| `filetypes` | `skill-filetypes` | `filetypes-agent` | `filetypes-router-agent` |
| `present:slides` (implement) | `skill-slides:assemble` | `slides:assemble-agent` (invalid identifier) | `slidev-assembly-agent` (representative primary agent) |

`routing_agents`/`routing_agents_hard` replace derivation with explicit declaration, ground-
truthed against each skill's own `subagent_type` dispatch (never guessed): every value names a
real, on-disk agent file, verified by `lint-routing-wiring.sh` Check B and by
`test-routing-resolution.sh` Assert 2.

**Compound multi-stage skills** (e.g. `skill-slides`, which internally dispatches to
`slides-research-agent`, `pptx-assembly-agent`, or `slidev-assembly-agent` depending on
`workflow_type`/`output_format`) have no single "real" agent per task_type. The convention:
declare the REPRESENTATIVE primary agent for that op — the one the default/most common workflow
path uses — rather than skip the declaration or invent a fake compound agent name. The `:` never
enters an agent name.

**`general-*` declarations stay visible, not silent**: `lint-routing-wiring.sh` Check D reports
(never fails) every `(op, task_type)` pair whose declared agent is a `general-*` agent, so a
deliberate general-routing decision (e.g. `memory`, `email` research) is auditable rather than
indistinguishable from an oversight.

**Audit record: no colon-suffixed `routing_agents`/`routing_agents_hard` value exists (negative
result)**. The now-deleted skill-level `routing.implement` block used colon-suffixed compound
VALUES for a brief period (e.g. `present`'s `"present:grant"` resolving to a skill name like
`"skill-grant:assemble"`, where the colon suffix encoded a sub-operation `workflow_type` mode a
caller would split out); that encoding disappeared with the block, mooting the question for the
skill layer. A `contains(":")` sweep of `routing_agents`/`routing_agents_hard` VALUES (not keys —
compound-base KEYS like `"founder:deck"` are the normal, expected alias mechanism documented
above) across all manifests returns nothing: zero live instances. The resolution is to record
this negative audit result rather than build a colon-splitting encoding that has no present use.
Re-run the sweep before reopening the question:
```bash
jq -r '
  ["routing_agents","routing_agents_hard"][] as $b
  | (.[$b] // {}) | to_entries[] | .value | to_entries[]
  | select(.value | contains(":"))
  | "\($b).\(.key)"
' agent-system/extensions/*/manifest.json
```

**Audit record: a nonexistent-agent declaration is already a hard deploy failure (confirmed,
not newly built)**. `lint-routing-wiring.sh` Check B already fails on any
`routing_agents`/`routing_agents_hard` value naming a nonexistent agent file, and is already
wired as `verify-deploy.sh` gate 7 (hard fail) — this makes the original defect this task
collapses the ladder in response to (a manifest naming a nonexistent dispatch target, shipped
silently) impossible to reintroduce under the collapsed model without a hard CI-equivalent
failure.

---

## Adding Routing to a New Extension

```json
{
  "name": "myext",
  "task_type": "mytype",
  "routing_agents": {
    "research": { "mytype": "mytype-research-agent" },
    "plan": { "mytype": "planner-agent" },
    "implement": { "mytype": "mytype-implementation-agent" }
  }
}
```

Add `routing_agents_hard` only if hard-mode agents actually exist for this extension. Ground-truth
every `routing_agents` value against the routed skill's own `subagent_type` dispatch line — never
derive it. Run `lint-routing-wiring.sh --verbose` before committing; it fails loudly on a missing
counterpart key or a non-existent agent file.

---

## Related Files

- `scripts/lib/manifest-routing-lib.sh` — the one ladder implementation, plus the
  `hard_contracts` sibling ladder, `routing_lookup_flat()`
- `scripts/command-route-agent.sh` — agent resolution (`/orchestrate`, `/orchestrate --hard`) —
  the sole surviving routing resolver
- `scripts/lint/lint-routing-wiring.sh` — wiring-validation gate (verify-deploy.sh gate7)
- `scripts/tests/test-routing-resolution.sh` — table-driven parity test
- `scripts/orchestrate-build-dispatch.sh` — Stage 3.5 Dispatch Prep, the `hard_contracts` block's
  sole consumer
- `context/guides/hard-mode-routing.md` — `--hard`-specific resolution detail and history
