# Manifest Routing Schema

This document is the authoritative description of the consolidated routing model: the five
manifest blocks (`routing`, `routing_hard`, `routing_agents`, `routing_agents_hard`,
`hard_contracts`), the single five-step first-match-wins ladder every routing consumer shares,
core-manifest identification, `routing_exempt`'s narrowed meaning, and the rule that agent names
are always declared data, never derived strings.

**Scope**: This document covers the manifest-level routing schema. For the `--hard`-specific
resolution path and its historical divergence (now eliminated), see
`context/guides/hard-mode-routing.md`. For the CLAUDE.md-level routing summary consumed by
agents at dispatch time, see the "Routing Mechanism" section of the generated CLAUDE.md (sourced
from `merge-sources/claudemd.md`).

---

## The Five Blocks

Every extension manifest may declare up to four **two-level** routing blocks, all sharing the
same `{ op: { task_type: value } }` shape (`op` is `"research"`, `"plan"`, or `"implement"`, plus
occasionally an extension-specific op like `present`'s `"critique"`), plus one **one-level**
block, `hard_contracts`, with a genuinely different shape (see its own subsection below):

| Block | Value type | Consumed by |
|-------|-----------|-------------|
| `routing` | skill name (e.g. `"skill-epi-research"`) | `command-route-skill.sh` (standard mode) |
| `routing_hard` | skill name (e.g. `"skill-lean-research-hard"`) | `command-route-skill.sh` (`--hard` mode) |
| `routing_agents` | agent name, no `.md` suffix (e.g. `"epi-research-agent"`) | `command-route-agent.sh` (standard mode) |
| `routing_agents_hard` | agent name (e.g. `"lean-research-hard-agent"`) | `command-route-agent.sh` (`--hard` mode) |
| `hard_contracts` | array of contract paths/`replace:` entries (see below) | `orchestrate-build-dispatch.sh`'s Stage 3.5 Dispatch Prep, via `routing_lookup_flat()` |

`routing`/`routing_hard` resolve which **skill** a command (`/research`, `/plan`, `/implement`)
invokes. `routing_agents`/`routing_agents_hard` resolve which **agent** `/orchestrate` and
`/orchestrate --hard` dispatch directly (bypassing the skill layer). Both pairs are read by the
exact same underlying ladder — only the block name and the resolver script differ. `hard_contracts`
is unrelated to either pair — it does not resolve a skill or an agent name, it resolves the list
of behavioral-contract files injected into a `--hard` dispatch's prompt.

**Completeness rule**: every key present in `routing.{op}` MUST have a counterpart key in
`routing_agents.{op}` on the same manifest, and every key in `routing_hard.{op}` MUST have a
counterpart in `routing_agents_hard.{op}`. `lint-routing-wiring.sh` (Checks A and C) enforces
this as a hard FAIL, not a silent gap — this is the mechanical backstop against the defect class
that let sed-derived agent names silently resolve to non-existent files. `hard_contracts` has no
counterpart-key rule; it is independently optional.

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

All four blocks resolve through ONE ladder, implemented once in
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
every consumer: `command-route-skill.sh`, `command-route-agent.sh`, and `skill-orchestrate`
(both effort modes share this one engine today). Before the standalone hard-mode orchestrator was
merged into `skill-orchestrate` and then deleted, it used a different, undocumented rule
(last-match-wins, no core exclusion) — see `context/guides/hard-mode-routing.md` for that
history.

Only Step 5's emptiness is a true "miss" — a caller's own default (e.g. `skill-epi-research`,
`general-research-agent`) is substituted OUTSIDE the ladder, by the caller, never inside
`routing_lookup()` itself.

### The `-hard` append fallback (skill resolution only)

`command-route-skill.sh` has one additional fallback step, Step 4e, that `command-route-agent.sh`
does NOT have: if hard-mode resolution (Steps 1-4 against `routing_hard`) misses entirely, it
tries appending `-hard` to the already-resolved standard `SKILL_NAME`, using the result only if
`.claude/skills/${candidate}-hard/SKILL.md` exists on disk (a safety gate against resolving to an
undeployed skill). `command-route-agent.sh` has no equivalent — a hard-mode agent miss falls
through directly to the caller-supplied hard default (a `-hard`-suffixed agent name), never
to the standard `routing_agents` block. This asymmetry is deliberate: skill names follow a
predictable `-hard` suffix convention; agent names do not.

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

## `.task_type` (singular) vs. `.routing.{op}` keys (aliases)

Every manifest carries a singular top-level `.task_type` string (e.g. epidemiology's is `"epi"`),
but its `.routing.{op}` blocks may declare SEVERAL alias keys resolving to the same extension —
epidemiology declares `epi`, `epi:study`, AND `epidemiology`, all routing to
`skill-epi-research`/`skill-epi-implement`. The singular field is insufficient by itself for
directory/extension resolution; `routing_manifest_for_task_type()` in the shared library scans
the `.routing.{research,plan,implement}` keys (exact or compound-base match) instead — the same
data every other ladder step already reads.

**Directory-resolution-via-routing-keys convention**: before this task, `skill-orchestrate`
(base mode) resolved an extension's directory by assuming `directory_name == task_type`
(`.claude/extensions/${TASK_TYPE}/manifest.json`) — which silently failed for `epi` (the
extension directory is `epidemiology`, not `epi`) and only worked for `neovim`/`lean4` because a
hardcoded `case` statement masked the bug. `routing_manifest_for_task_type()` replaces
directory-name guessing entirely: it finds the right manifest by what it DECLARES, not by what
its directory happens to be named.

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

---

## Adding Routing to a New Extension

```json
{
  "name": "myext",
  "task_type": "mytype",
  "routing": {
    "research": { "mytype": "skill-mytype-research" },
    "implement": { "mytype": "skill-mytype-implementation" }
  },
  "routing_agents": {
    "research": { "mytype": "mytype-research-agent" },
    "plan": { "mytype": "planner-agent" },
    "implement": { "mytype": "mytype-implementation-agent" }
  }
}
```

Add `routing_hard`/`routing_agents_hard` only if hard-mode skills/agents actually exist for this
extension. Ground-truth every `routing_agents` value against the routed skill's own
`subagent_type` dispatch line — never derive it. Run `lint-routing-wiring.sh --verbose` before
committing; it fails loudly on a missing counterpart key or a non-existent agent file.

---

## Related Files

- `scripts/lib/manifest-routing-lib.sh` — the one ladder implementation, plus the
  `hard_contracts` sibling ladder, `routing_lookup_flat()`
- `scripts/command-route-skill.sh` — skill resolution (`/research`, `/plan`, `/implement`)
- `scripts/command-route-agent.sh` — agent resolution (`/orchestrate`, `/orchestrate --hard`)
- `scripts/lint/lint-routing-wiring.sh` — wiring-validation gate (verify-deploy.sh gate7)
- `scripts/tests/test-routing-resolution.sh` — table-driven parity test
- `scripts/orchestrate-build-dispatch.sh` — Stage 3.5 Dispatch Prep, the `hard_contracts` block's
  sole consumer
- `context/guides/hard-mode-routing.md` — `--hard`-specific resolution detail and history
