# Mathlib Overview

Mathlib is the comprehensive mathematics library for Lean 4.

## Key Namespaces

### Algebra
- `Algebra.Group` - Group theory
- `Algebra.Ring` - Ring theory
- `Algebra.Field` - Field theory
- `Algebra.Order` - Ordered structures

### Analysis
- `Analysis.Calculus` - Calculus and derivatives
- `Analysis.Topology` - Topological spaces
- `Analysis.Measure` - Measure theory

### Data
- `Data.Nat` - Natural numbers
- `Data.Int` - Integers
- `Data.Rat` - Rationals
- `Data.Real` - Real numbers
- `Data.List` - Lists
- `Data.Set` - Sets
- `Data.Finset` - Finite sets

### Logic
- `Logic.Basic` - Basic logic
- `Logic.Equiv` - Equivalences

### Order
- `Order.Lattice` - Lattice theory
- `Order.Galois` - Galois connections

### Topology
- `Topology.Basic` - Topological spaces
- `Topology.MetricSpace` - Metric spaces

## Common Imports

### For Natural Numbers
```lean
import Mathlib.Data.Nat.Basic
import Mathlib.Data.Nat.GCD
```

### For Lists
```lean
import Mathlib.Data.List.Basic
import Mathlib.Data.List.Sort
```

### For Sets
```lean
import Mathlib.Data.Set.Basic
import Mathlib.Data.Set.Finite
```

### For Analysis
```lean
import Mathlib.Analysis.Calculus.Deriv
import Mathlib.Analysis.SpecialFunctions.Log.Basic
```

## Finding Lemmas

Use the search decision tree:
1. `lean_local_search` - Check if name exists
2. `lean_leansearch` - Natural language query
3. `lean_loogle` - Type pattern matching
4. `lean_leanfinder` - Semantic concept search

## Naming Conventions

### Theorems
- Prefix indicates type: `Nat.`, `List.`, `Set.`
- Suffix indicates conclusion: `_add`, `_mul`, `_comm`
- Examples: `Nat.add_comm`, `List.length_append`

### Operations
- `add`, `mul`, `sub`, `div` - Arithmetic
- `union`, `inter` - Set operations
- `append`, `concat` - List operations

### Properties
- `_comm` - Commutativity
- `_assoc` - Associativity
- `_iff` - Bidirectional implication
- `_of_` - Construction from
- `_to_` - Conversion to
