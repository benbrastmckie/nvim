# Formal Extension

Formal reasoning extension for mathematical logic, mathematics, and physics research. Provides four research agents (formal, logic, math, physics) covering modal logic and Kripke semantics, lattice and category theory, and dynamical systems. Implementation tasks fall through to `general-implementation-agent` by design (see the Research-Only Pattern note below).

## Overview

| Task Type | Agent | Domains |
|-----------|-------|---------|
| `formal` | formal-research-agent | Multi-domain formal reasoning (coordinator) |
| `logic` | logic-research-agent | Modal logic, Kripke semantics, proof theory, decidability |
| `math` | math-research-agent | Algebra, lattice theory, category theory, topology |
| `physics` | physics-research-agent | Dynamical systems, flows, bifurcations |

This extension is **research-only**: it provides no dedicated implementation agents or skills. `/implement` on a formal/logic/math/physics task uses the core `skill-implementer` -> `general-implementation-agent` path. See the Research-Only Pattern section below for why this is intentional.

## Installation

Loaded via `<leader>ac` in Neovim. Once loaded, `formal`, `logic`, `math`, and `physics` become recognized task types and their research agents are available.

## Commands

This extension provides no commands of its own. Use the core `/research`, `/plan`, and `/implement` commands with tasks typed as `formal`, `logic`, `math`, or `physics`.

## Architecture

```
formal/
├── manifest.json              # Extension configuration
├── EXTENSION.md               # CLAUDE.md merge content
├── index-entries.json         # Context discovery entries
├── README.md                  # This file
│
├── skills/
│   ├── skill-formal-research/     # Multi-domain coordination
│   ├── skill-logic-research/      # Logic domain research
│   ├── skill-math-research/       # Math domain research
│   └── skill-physics-research/    # Physics domain research
│
├── agents/
│   ├── formal-research-agent.md   # Multi-domain formal research coordinator
│   ├── logic-research-agent.md    # Modal logic, Kripke, proof theory
│   ├── math-research-agent.md     # Algebra, lattices, categories, topology
│   └── physics-research-agent.md  # Dynamical systems, formalization
│
└── context/
    └── project/
        ├── logic/              # Logic domain knowledge
        ├── math/               # Math domain knowledge
        └── physics/            # Physics domain knowledge
```

## Skill-Agent Mapping

| Skill | Agent | Purpose |
|-------|-------|---------|
| skill-formal-research | formal-research-agent | Multi-domain formal research coordination |
| skill-logic-research | logic-research-agent | Modal logic and Kripke semantics research |
| skill-math-research | math-research-agent | Algebra, lattice theory, category theory research |
| skill-physics-research | physics-research-agent | Physics formalization research |

## Language Routing

Automatic routing based on task keywords:

### Logic Domain (triggers logic-research-agent)
- Modal logic, Kripke, accessibility, possible worlds
- Proof theory, sequent calculus, natural deduction
- Completeness, soundness, decidability
- Temporal logic, epistemic logic

### Math Domain (triggers math-research-agent)
- Lattice, partial order, complete lattice
- Group, ring, field, monoid
- Category, functor, natural transformation
- Topology, metric space, topological space

### Physics Domain (triggers physics-research-agent)
- Dynamical systems, fixed points, orbits
- Flow, trajectory, ergodic
- Chaos, Lyapunov, bifurcation

### Multi-Domain (triggers formal-research-agent)
Tasks that span two or more of the above domains, or that require coordination across them.

## Workflow

```
/research <task>            (task_type: formal | logic | math | physics)
    |
    v
skill-{domain}-research -> {domain}-research-agent
    |  (loads domain context from project/{domain}/)
    v
specs/{NNN}_{SLUG}/reports/MM_{slug}.md
    |
    v
/plan <task>
    |  (uses core planner-agent)
    v
specs/{NNN}_{SLUG}/plans/MM_{slug}.md
    |
    v
/implement <task>
    |  (falls through to general-implementation-agent)
    v
specs/{NNN}_{SLUG}/summaries/MM_{slug}-summary.md
```

## Research-Only Pattern

**Important**: This extension provides only research agents. It deliberately omits implementation agents and skills. When you run `/implement` on a formal/logic/math/physics task, the implement command routes to the core `skill-implementer` -> `general-implementation-agent` path instead of a domain-specific implementer.

### Why This Is Intentional

1. **Formal research artifacts are typically text, proofs, or specifications**, not code in a specialized language. General file editing suffices.
2. **Domain-specific implementers for formal reasoning already exist as separate extensions** (e.g., the `lean` extension for Lean 4 proofs). If a task requires Lean implementation, it should be typed as `lean4` rather than `logic` or `math`.
3. **The implementation phase for formal research tasks is usually mechanical** - converting research findings into a plan and executing that plan through standard file edits. No specialized implementation agent is needed.

### How to Tell If You Need a Lean Implementation Instead

- If your task involves writing `.lean` files -> use `task_type: "lean4"` (lean extension)
- If your task involves writing Typst/LaTeX proofs or specifications -> use the generic fallthrough
- If your task involves writing research reports, notes, or expositions -> use the generic fallthrough

### Router Behavior

The extension's `manifest.json` declares only research skills. The core orchestrator's skill-selection logic falls through to `skill-implementer` when no domain-specific implementation skill is found. This is not a bug or missing configuration - it is the intended dispatch path for this extension.

## Output Artifacts

| Phase | Artifact |
|-------|----------|
| Research | `specs/{NNN}_{SLUG}/reports/MM_{slug}.md` |
| Plan | `specs/{NNN}_{SLUG}/plans/MM_{slug}.md` |
| Implementation | Task-specific files plus `specs/{NNN}_{SLUG}/summaries/MM_{slug}-summary.md` |

## Key Patterns

### Domain Context Loading

Each research agent loads its domain-specific context on demand via the adaptive query pattern from `.claude/context/patterns/context-discovery.md`. The logic agent loads `project/logic/`, the math agent loads `project/math/`, etc. Cross-domain references are loaded by the `formal-research-agent` when coordinating multi-domain tasks.

### Formal Symbol Conventions

All Unicode formal symbols in documentation must be wrapped in backticks, per the documentation standards. Examples: `` `□` ``, `` `◇` ``, `` `⊢` ``, `` `⊨` ``, `` `∀` ``, `` `∃` ``.

## Context References

- `@.claude/extensions/formal/context/project/logic/README.md`
- `@.claude/extensions/formal/context/project/math/README.md`
- `@.claude/extensions/formal/context/project/physics/README.md`

## References

- [Modal Logic](https://plato.stanford.edu/entries/logic-modal/) - Stanford Encyclopedia of Philosophy
- [Lattice Theory](https://en.wikipedia.org/wiki/Lattice_%28order%29)
- [Category Theory](https://ncatlab.org/nlab/show/HomePage) - nLab
- [Dynamical Systems](https://www.scholarpedia.org/article/Dynamical_systems)
