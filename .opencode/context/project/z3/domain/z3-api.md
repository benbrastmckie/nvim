# Z3 Python API Reference

## Installation

```bash
pip install z3-solver
```

## Core Types

### Variables
```python
from z3 import Int, Real, Bool, BitVec

x = Int('x')           # Integer
y = Real('y')          # Real number
b = Bool('b')          # Boolean
v = BitVec('v', 32)    # 32-bit bitvector
```

### Arrays and Functions
```python
from z3 import Array, IntSort, RealSort, Function

arr = Array('arr', IntSort(), IntSort())  # Int -> Int array
f = Function('f', IntSort(), IntSort())   # Function
```

## Solver API

### Basic Usage
```python
from z3 import Solver, sat, unsat

solver = Solver()
solver.add(x > 0)
solver.add(x < 10)

if solver.check() == sat:
    model = solver.model()
    print(model[x])  # e.g., 1
```

### Incremental Solving
```python
solver.push()           # Save state
solver.add(x == 5)
solver.check()
solver.pop()            # Restore state
```

### Optimization
```python
from z3 import Optimize

opt = Optimize()
opt.add(x >= 0)
opt.maximize(x)
opt.check()
```

## Bitvector Operations

```python
from z3 import BitVec, BitVecVal, ULT, ULE, Extract

a = BitVec('a', 32)
b = BitVec('b', 32)

# Bitwise operations
a & b           # AND
a | b           # OR
a ^ b           # XOR
~a              # NOT
a << 2          # Left shift
a >> 2          # Right shift

# Unsigned comparisons
ULT(a, b)       # a < b (unsigned)
ULE(a, b)       # a <= b (unsigned)

# Extract bits
Extract(7, 0, a)  # Get bits 0-7
```

## Tactics

```python
# Simplify expressions
simplify(expr)

# Apply tactics
from z3 import Tactic
t = Tactic('solve-eqs')
result = t(goal)
```

## Debugging

```python
# Get unsat core
solver.check()
core = solver.unsat_core()

# Statistics
solver.statistics()
```
