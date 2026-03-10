## Formal Reasoning Extension

Language routing and context for formal mathematical reasoning including logic, mathematics, and physics.

### Language Routing

| Language | Description | Use Cases |
|----------|-------------|-----------|
| `formal` | General formal reasoning | Multi-domain formal tasks |
| `logic` | Mathematical logic | Modal logic, Kripke semantics, proof theory |
| `math` | Mathematics | Algebra, lattice theory, category theory, topology |
| `physics` | Physics | Dynamical systems, formalization |

### Skill-to-Agent Mapping

| Skill | Agent | Purpose |
|-------|-------|---------|
| skill-formal-research | formal-research-agent | Multi-domain formal research coordination |
| skill-logic-research | logic-research-agent | Modal logic and Kripke semantics research |
| skill-math-research | math-research-agent | Mathematics research (algebra, lattices, categories) |
| skill-physics-research | physics-research-agent | Physics formalization research |

### Domain Routing

Automatic routing based on task keywords:

**Logic Domain** (triggers logic-research-agent):
- Modal logic, Kripke, accessibility, possible worlds
- Proof theory, sequent calculus, natural deduction
- Completeness, soundness, decidability
- Temporal logic, epistemic logic

**Math Domain** (triggers math-research-agent):
- Lattice, partial order, complete lattice
- Group, ring, field, monoid
- Category, functor, natural transformation
- Topology, metric space, topological space

**Physics Domain** (triggers physics-research-agent):
- Dynamical systems, fixed points, orbits
- Flow, trajectory, ergodic
- Chaos, Lyapunov, bifurcation

### Context Import References

Load context files on-demand:

```
Logic domain:
@.claude/context/project/logic/README.md
@.claude/context/project/logic/domain/kripke-semantics-overview.md

Math domain:
@.claude/context/project/math/README.md
@.claude/context/project/math/lattice-theory/lattices.md

Physics domain:
@.claude/context/project/physics/README.md
@.claude/context/project/physics/dynamical-systems/dynamical-systems.md
```
