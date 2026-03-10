# BitVector Operations

BitVec patterns for state representation and manipulation in Z3.

## Overview

BitVectors can represent sets where:
- N bits = N elements
- Bit i set = element i is in the set
- Set operations map to bitwise operations

## Core Concepts

### State Space

```python
N = 16  # Configurable, typically 8, 16, or 32

# Full state (all elements)
FULL = (1 << N) - 1  # 0xFFFF for N=16

# Empty state
NULL = 0

# Number of possible states
total_states = 1 << N  # 2^N = 65536 for N=16
```

### Creating BitVectors

```python
import z3

# Z3 variable
state = z3.BitVec('state', N)

# From integer
concrete = z3.BitVecVal(5, N)  # Binary: ...0101

# Named variables
x = z3.BitVec('x', N)
y = z3.BitVec('y', N)
```

## Set Operations

### Containment (Subset)

```python
def is_subset(s1, s2):
    """s1 is a subset of s2."""
    # s1 is contained in s2 if their AND equals s1
    return (s1 & s2) == s1

# Examples:
# 0101 is subset of 0111 (true: 0101 & 0111 = 0101)
# 0101 is subset of 0100 (false: 0101 & 0100 = 0100)
```

### Proper Subset

```python
def proper_subset(s1, s2):
    """s1 is a proper subset of s2 (contained but smaller)."""
    return z3.And(is_subset(s1, s2), s1 != s2)
```

### Union

```python
def union(s1, s2):
    """Union of s1 and s2."""
    return s1 | s2

# Example: union(0101, 0011) = 0111
```

### Intersection

```python
def intersection(s1, s2):
    """Intersection of s1 and s2."""
    return s1 & s2

# Example: intersection(0111, 0011) = 0011
```

### Overlap

```python
def overlap(s1, s2):
    """s1 and s2 share at least one element."""
    return (s1 & s2) != 0

def disjoint(s1, s2):
    """s1 and s2 share no element."""
    return (s1 & s2) == 0
```

### Difference

```python
def difference(s1, s2):
    """Elements of s1 that are not in s2."""
    return s1 & ~s2

# Example: difference(0111, 0011) = 0100
```

### Complement

```python
def complement(s, N):
    """All elements except those in s."""
    FULL = (1 << N) - 1
    return ~s & FULL
```

## Utility Functions

### bitvec_to_set

```python
def bitvec_to_set(bitvec_val, N):
    """Convert integer/BitVec to set of element indices."""
    if hasattr(bitvec_val, 'as_long'):
        bitvec_val = bitvec_val.as_long()

    elements = set()
    for i in range(N):
        if bitvec_val & (1 << i):
            elements.add(i)
    return elements

# Example: bitvec_to_set(5, 4) -> {0, 2}  (binary 0101)
```

### set_to_bitvec

```python
def set_to_bitvec(element_set, N):
    """Convert set of indices to bitvector value."""
    value = 0
    for i in element_set:
        value |= (1 << i)
    return value

# Example: set_to_bitvec({0, 2}, 4) -> 5  (binary 0101)
```

### int_to_binary

```python
def int_to_binary(n, width):
    """Convert integer to binary string with fixed width."""
    return format(n, f'0{width}b')

# Example: int_to_binary(5, 8) -> "00000101"
```

### pretty_set_print

```python
def pretty_set_print(element_set):
    """Format set of elements for display."""
    if not element_set:
        return "{}"
    return "{" + ", ".join(str(s) for s in sorted(element_set)) + "}"

# Example: pretty_set_print({0, 2, 5}) -> "{0, 2, 5}"
```

## Constraint Patterns

### Non-Empty Sets

```python
# Set must have at least one element
non_empty = state != 0

# Set must have at least k elements (using popcount)
# See cardinality constraints below
```

### Cardinality Constraints

```python
def has_exactly_n_elements(state, n, N):
    """State has exactly n elements."""
    # Create boolean for each bit
    bits = [z3.Extract(i, i, state) == 1 for i in range(N)]
    # Use PbEq for pseudo-boolean equality
    return z3.PbEq([(b, 1) for b in bits], n)
```

### At Least / At Most

```python
def has_at_least_n_elements(state, n, N):
    """State has at least n elements."""
    bits = [z3.Extract(i, i, state) == 1 for i in range(N)]
    return z3.PbGe([(b, 1) for b in bits], n)

def has_at_most_n_elements(state, n, N):
    """State has at most n elements."""
    bits = [z3.Extract(i, i, state) == 1 for i in range(N)]
    return z3.PbLe([(b, 1) for b in bits], n)
```

## Iteration Patterns

### Enumerate All States

```python
def enumerate_states(N):
    """Generator for all possible states."""
    for i in range(1 << N):
        yield i
```

### Enumerate Non-Empty States

```python
def enumerate_nonempty_states(N):
    """Generator for all non-empty states."""
    for i in range(1, 1 << N):
        yield i
```

### Enumerate Subsets

```python
def enumerate_subsets(state_val, N):
    """Generator for all subsets of a given state."""
    for i in range(1 << N):
        if (i & state_val) == i:
            yield i
```

## Model Extraction

```python
def extract_state_value(model, bitvec_var):
    """Extract concrete state value from Z3 model."""
    val = model[bitvec_var]
    if val is None:
        return None
    return val.as_long()

def format_state(state_val, N):
    """Format state value for display."""
    elements = bitvec_to_set(state_val, N)
    binary = int_to_binary(state_val, N)
    return f"{elements} (binary: {binary})"
```

## Common Operations Matrix

| Operation | Python | Z3 | Description |
|-----------|--------|-----|-------------|
| Union | `\|` | `\|` | Set union |
| Intersection | `&` | `&` | Set intersection |
| Difference | `& ~` | `& ~` | Set difference |
| Subset | `(a & b) == a` | Same | Containment check |
| Overlap | `(a & b) != 0` | Same | Shared elements? |
| Disjoint | `(a & b) == 0` | Same | No shared elements? |
| Complement | `~a & FULL` | Same | All except a |
| Empty check | `a == 0` | Same | Empty set? |
| Full check | `a == FULL` | Same | Full set? |

## Performance Considerations

### Small N for Testing

```python
# Use small N (4-8) for unit tests
# Use larger N (16-32) for realistic examples
TEST_N = 4
PROD_N = 16
```

### Avoid Expensive Operations

```python
# Counting bits is expensive in Z3
# Use constraints instead of computing popcount

# Instead of: popcount(state) == k
# Use: PbEq constraint (more efficient)
```

### Cache State Conversions

```python
# For repeated conversions, cache results
_state_cache = {}

def cached_to_set(val, N):
    key = (val, N)
    if key not in _state_cache:
        _state_cache[key] = bitvec_to_set(val, N)
    return _state_cache[key]
```
