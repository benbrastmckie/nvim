# Loogle API Documentation

## Overview

Loogle is a search tool for Lean 4 and Mathlib that enables searching for definitions, theorems, and lemmas by:
- Constant names (e.g., `Real.sin`)
- Lemma name substrings (e.g., `"differ"`)
- Type patterns (e.g., `?a -> ?b -> ?a /\ ?b`)
- Conclusion patterns (e.g., `|- _ < _ -> _`)

## Query Syntax

### 1. Search by Constant Name

**Syntax**: Unquoted identifier

**Example**: `Real.sin`

**Matches**: All declarations mentioning `Real.sin` in their type

### 2. Search by Name Fragment

**Syntax**: Quoted string

**Example**: `"differ"`

**Matches**: Declarations with "differ" in name (case-insensitive)

### 3. Search by Type Pattern

**Syntax**: Term with metavariables (`_` or `?name`)

**Metavariables**:
- `_` - Anonymous (each independent)
- `?name` - Named (same name = same value)

**Examples**:

```
# Find multiplication with power
_ * (_ ^ _)

# Find conjunction introduction
?a -> ?b -> ?a /\ ?b

# Parameter order doesn't matter
(?a -> ?b) -> List ?a -> List ?b  # Finds List.map
```

### 4. Search by Conclusion

**Syntax**: `|- pattern`

**Matches**: Only the conclusion (right of all `->` and `forall`)

**Examples**:

```
# Conclusion with specific shape
|- tsum _ = _ * tsum _

# Conclusion with hypothesis
|- _ < _ -> tsum _ < tsum _
```

### 5. Combined Filters

**Syntax**: Comma-separated filters

**Logic**: All filters must match (AND)

**Examples**:

```
# Multiple constants
Real.sin, tsum

# Constant + name fragment
List.map, "assoc"
```

## Web API

### HTTP Request

```http
GET https://loogle.lean-lang.org/json?q={query}
```

**Parameters**:
- `q` (required): URL-encoded query string

### Response

```json
{
  "header": "Found 5 declarations...",
  "count": 3,
  "hits": [
    {
      "name": "List.map",
      "type": "forall {a b}, (a -> b) -> List a -> List b",
      "module": "Init.Data.List.Basic",
      "doc": "Map a function over a list"
    }
  ]
}
```

## Common Errors

| Error Message | Cause | Solution |
|---------------|-------|----------|
| `Unknown identifier 'X'` | Unresolved name | Use quoted string or qualified name |
| `Name pattern is too general` | Pattern too short | Use longer pattern (>1 char) |

## Best Practices

1. **Use Type Patterns** for precise searches
2. **Use Named Metavariables** for non-linear patterns
3. **Combine Filters** for narrow results
4. **Always Timeout** requests

## References

- **Loogle Web**: https://loogle.lean-lang.org/
- **Mathlib Docs**: https://leanprover-community.github.io/mathlib4_docs/
