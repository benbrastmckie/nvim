# SMT Patterns and Tactics

SMT-LIB patterns, Z3 tactics, and debugging techniques.

## SMT-LIB Format

Z3 can read/write SMT-LIB2 format for constraint exchange.

### Basic Structure

```smt2
; Declare sorts
(declare-sort MySort 0)

; Declare constants/functions
(declare-const x Int)
(declare-const y Int)
(declare-fun f (Int) Int)

; Assert constraints
(assert (> x 0))
(assert (< y 10))

; Check satisfiability
(check-sat)

; Get model
(get-model)
```

### Converting Python to SMT-LIB

```python
import z3

x = z3.Int('x')
y = z3.Int('y')
solver = z3.Solver()
solver.add(x > 0)
solver.add(y > x)

# Export to SMT-LIB2
print(solver.sexpr())
```

### Loading SMT-LIB

```python
solver = z3.Solver()
solver.from_string("""
(declare-const x Int)
(assert (> x 0))
""")
result = solver.check()
```

## Common Tactics

### Simplification

```python
# Basic simplification
z3.simplify(expr)

# Tactic form
t = z3.Tactic('simplify')
goal = z3.Goal()
goal.add(expr)
result = t(goal)
```

**Simplify options**:
- `som`: Sum of monomials form
- `sort_sums`: Sort sums
- `flat`: Flatten nested And/Or
- `arith_lhs`: Move arithmetic to LHS

### Propagation

```python
# Propagate values
t = z3.Tactic('propagate-values')

# Propagate ineqs (bounds)
t = z3.Tactic('propagate-ineqs')
```

### Solving Equations

```python
# Gaussian elimination for linear equations
t = z3.Tactic('solve-eqs')
```

### Bit-Blasting

For bitvector reasoning:

```python
# Convert bitvector to SAT
t = z3.Tactic('bit-blast')

# Then solve with SAT
combined = z3.Then('bit-blast', 'sat')
```

### Quantifier Elimination

```python
# Eliminate quantifiers (when possible)
t = z3.Tactic('qe')

# Light version
t = z3.Tactic('qe-light')
```

## Tactic Combinators

```python
# Sequential
combined = z3.Then('simplify', 'solve-eqs', 'sat')

# Parallel (first to succeed)
combined = z3.OrElse('tactic1', 'tactic2')

# Repeat until fixpoint
repeated = z3.Repeat('simplify')

# Try tactic, use default if fails
combined = z3.TryFor('tactic', 1000)  # timeout in ms

# With parameter
combined = z3.With('simplify', som=True)
```

## Built-in Solvers

```python
# Default solver
solver = z3.Solver()

# Specific solver
solver = z3.SolverFor('QF_BV')  # Quantifier-free bitvectors
solver = z3.SolverFor('QF_LIA')  # Quantifier-free linear integer arithmetic
```

**Common logics**:
| Logic | Description |
|-------|-------------|
| QF_BV | Quantifier-free bitvectors |
| QF_LIA | Quantifier-free linear integer arithmetic |
| QF_LRA | Quantifier-free linear real arithmetic |
| QF_NIA | Quantifier-free nonlinear integer arithmetic |
| LIA | Linear integer arithmetic with quantifiers |
| BV | Bitvectors with quantifiers |

## Debugging Techniques

### Unsat Core

Find minimal conflicting constraints:

```python
solver = z3.Solver()
solver.set('unsat_core', True)

# Add constraints with labels
a = z3.Bool('a')
b = z3.Bool('b')
solver.assert_and_track(x > 0, a)
solver.assert_and_track(x < 0, b)

if solver.check() == z3.unsat:
    core = solver.unsat_core()
    print(core)  # [a, b]
```

### Proof Generation

```python
solver = z3.Solver()
solver.set('proof', True)
solver.add(constraints)

if solver.check() == z3.unsat:
    proof = solver.proof()
    print(proof)
```

### Model Inspection

```python
model = solver.model()

# Print all assignments
for decl in model.decls():
    print(f"{decl.name()} = {model[decl]}")

# Evaluate complex expression
val = model.eval(expr, model_completion=True)
```

### Statistics

```python
result = solver.check()
stats = solver.statistics()
print(stats)
# Shows: time, memory, conflicts, etc.
```

## Performance Patterns

### Incrementality

```python
# Reuse solver state across related checks
solver = z3.Solver()
solver.add(shared_constraints)

for specific in test_cases:
    solver.push()
    solver.add(specific)
    result = solver.check()
    solver.pop()
```

### Assumptions vs Push/Pop

```python
# Assumptions: for temporary constraints
solver.check([temp1, temp2])

# Push/Pop: for related subproblems
solver.push()
solver.add(subproblem_constraints)
# ...
solver.pop()
```

### Timeout Handling

```python
solver.set('timeout', 10000)  # 10 seconds
result = solver.check()

if result == z3.unknown:
    # Timeout or gave up
    reason = solver.reason_unknown()
    print(f"Unknown: {reason}")
```

### Reducing Quantifiers

When possible, eliminate quantifiers:

```python
# Instead of:
z3.ForAll([x], x > 0)

# Enumerate if finite:
z3.And([val > 0 for val in possible_values])
```

## Common Pitfalls

### Mixing Sorts

```python
# Wrong: mixing Int and BitVec
x = z3.Int('x')
bv = z3.BitVec('bv', 32)
# x + bv  # Error!

# Right: convert explicitly
x + z3.BV2Int(bv)
z3.Int2BV(x, 32) + bv
```

### Quantifier Instantiation

Heavy quantifier use can cause timeout:

```python
# Risky: unbounded quantifier
z3.ForAll([x], constraint(x))

# Better: bounded or use patterns
z3.ForAll([x], constraint(x), patterns=[trigger(x)])
```

### Model Completion

```python
# By default, model only has used variables
model.eval(expr)  # May return expr unchanged

# Force complete model
model.eval(expr, model_completion=True)
```

## SMT-LIB Commands Reference

| Command | Purpose |
|---------|---------|
| `(check-sat)` | Check satisfiability |
| `(get-model)` | Get satisfying assignment |
| `(get-unsat-core)` | Get conflict core |
| `(push N)` | Push N context levels |
| `(pop N)` | Pop N context levels |
| `(reset)` | Reset solver state |
| `(echo "msg")` | Print message |
| `(set-option :opt val)` | Set option |
