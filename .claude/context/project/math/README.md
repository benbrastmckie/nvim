# Math Context Directory

Mathematical foundations context for formal reasoning.

## Directory Structure

| Directory | Content |
|-----------|---------|
| `algebra/` | Algebraic structures (groups, rings, monoids) |
| `lattice-theory/` | Lattice structures, complete lattices, bilattices |
| `order-theory/` | Partial orders, well-founded relations |
| `topology/` | Topological structures, Scott topology |
| `category-theory/` | Categories, functors, natural transformations |
| `foundations/` | Foundational mathematics (dependent type theory) |

## Canonical Files

### Algebra
- `algebra/groups-and-monoids.md` - Group and monoid structures
- `algebra/rings-and-fields.md` - Ring and field structures

### Lattice Theory
- `lattice-theory/lattices.md` - Lattice definitions and theorems
- `lattice-theory/bilattice-theory.md` - Bilattice structures

### Order Theory
- `order-theory/partial-orders.md` - Partial order structures
- `order-theory/monoidal-posets.md` - Monoidal partially ordered sets

### Topology
- `topology/topological-spaces.md` - Topological space definitions
- `topology/scott-topology.md` - Scott topology for domain theory

### Category Theory
- `category-theory/basics.md` - Category theory fundamentals
- `category-theory/monoidal-categories.md` - Monoidal category structures
- `category-theory/enriched-categories.md` - Enriched category theory
- `category-theory/lawvere-metric-spaces.md` - Lawvere metric spaces
- `category-theory/cauchy-completion.md` - Cauchy completion
- `category-theory/profunctors.md` - Profunctor theory

### Foundations
- `foundations/dependent-type-theory.md` - Dependent type theory

## Loading Pattern

Load files based on research topic:

```bash
# Find all math context files
ls -la .claude/context/project/math/*/
```

## Related Context

- Logic domain: `.claude/context/project/logic/` - Modal logic and Kripke semantics
- Physics domain: `.claude/context/project/physics/` - Dynamical systems
