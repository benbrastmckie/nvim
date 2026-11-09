# Z3 Extension

Z3 SMT solver development support with constraint-pattern guidance for Python bindings.

## Overview

| Task Type | Agent | Purpose |
|-----------|-------|---------|
| `z3` | z3-research-agent | Z3/SMT theory and API research |
| `z3` | z3-implementation-agent | Z3 constraint implementation |

## Installation

Loaded via the extension picker. Once loaded, `z3` becomes a recognized task type.

## Commands

No dedicated commands. Use the core research, plan, and implement phases (dispatched via `/orchestrate`) with `task_type: "z3"`.

## Skill-Agent Mapping

| Skill | Agent | Purpose |
|-------|-------|---------|
| skill-z3-research | z3-research-agent | Z3/SMT research |
| skill-z3-implementation | z3-implementation-agent | Z3 constraint implementation |

## Language Routing

| Task Type | Research Tools | Implementation Tools |
|-----------|----------------|---------------------|
| `z3` | WebSearch, WebFetch, Read | Read, Write, Edit, Bash(python, z3) |

## Key Patterns

- **Solver**: `z3.Solver()` for constraint solving
- **BitVec**: for finite-domain state representation
- **Incremental solving**: `push()`/`pop()` for efficiency when testing multiple constraints
- **Simplification**: `simplify(expr)` before adding to solver
- **Optimization**: `z3.Optimize()` for objective functions
- **Theory exploration**: Prefer ground terms; use quantifiers sparingly

## Common Operations

```python
import z3

s = z3.Solver()
x, y = z3.Ints('x y')
s.add(x + y == 10, x > 0, y > 0)
if s.check() == z3.sat:
    print(s.model())
```

## References

- [Z3 Documentation](https://microsoft.github.io/z3guide/)
- [Z3 Python bindings](https://z3prover.github.io/api/html/namespacez3py.html)
- [SMT-LIB standard](https://smt-lib.org/)
