# Z3 Context

This directory contains context files for Z3 SMT solver development.

## Structure

- `domain/` - Z3 API reference, SMT-LIB patterns
- `patterns/` - Constraint generation, bitvector operations

## Key Files

- `domain/z3-api.md` - Z3 Python API reference
- `domain/smt-patterns.md` - SMT-LIB patterns and tactics
- `patterns/constraint-generation.md` - Constraint building patterns
- `patterns/bitvector-operations.md` - BitVec state manipulation

## Z3 Quick Reference

### Solver
```python
from z3 import Solver, sat, unsat
solver = Solver()
solver.add(constraint)
if solver.check() == sat:
    model = solver.model()
```

### Types
| Type | Description |
|------|-------------|
| `Int('x')` | Integer variable |
| `Real('x')` | Real number variable |
| `Bool('x')` | Boolean variable |
| `BitVec('x', 32)` | 32-bit bitvector |

### Operations
| Operation | Description |
|-----------|-------------|
| `And`, `Or`, `Not` | Boolean |
| `If(c, t, f)` | Conditional |
| `ForAll`, `Exists` | Quantifiers |

## For Research

Load: `domain/z3-api.md`, `domain/smt-patterns.md`

## For Implementation

Load: `patterns/constraint-generation.md`, `patterns/bitvector-operations.md`
