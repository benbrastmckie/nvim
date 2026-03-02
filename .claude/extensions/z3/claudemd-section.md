## Z3 Extension

This project includes Z3 SMT solver development support via the z3 extension.

### Language Routing

| Language | Research Tools | Implementation Tools |
|----------|----------------|---------------------|
| `z3` | WebSearch, WebFetch, Read | Read, Write, Edit, Bash (python, z3) |

### Skill-Agent Mapping

| Skill | Agent | Purpose |
|-------|-------|---------|
| skill-z3-research | z3-research-agent | Z3/SMT research |
| skill-z3-implementation | z3-implementation-agent | Z3 constraint implementation |

### Z3 Patterns

- Use `z3.Solver()` for constraint solving
- BitVec for finite-domain state representation
- Incremental solving with `push()`/`pop()` for efficiency
- Use `simplify()` on expressions before adding to solver

### Common Operations

- Model checking: Define constraints, check `sat`, extract model
- Theory exploration: Use quantifiers sparingly, prefer ground terms
- Optimization: Use `z3.Optimize()` for objective functions
