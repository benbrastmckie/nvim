# LeanSearch API Integration Guide

## Overview

LeanSearch is a semantic search engine for Lean libraries using natural language queries. It uses machine learning to find relevant theorems and definitions based on conceptual similarity.

**API Endpoint**: `https://leansearch.net/api/search`

## Query Types

### Natural Language Queries

LeanSearch excels at natural language queries:

```
Query: "theorems about ring homomorphisms preserving multiplication"
Example Results:
  - RingHom.map_mul : f (x * y) = f x * f y
  - RingHom.map_pow : f (x ^ n) = f x ^ n
```

```
Query: "continuous functions on real numbers"
Example Results:
  - continuous_sin : Continuous Real.sin
  - continuous_exp : Continuous Real.exp
```

```
Query: "list concatenation is associative"
Example Results:
  - List.append_assoc : (l1 ++ l2) ++ l3 = l1 ++ (l2 ++ l3)
```

## API Specification

### HTTP Request

```http
POST https://leansearch.net/api/search
Content-Type: application/json
```

**Request Body**:
```json
{
  "query": "theorems about ring homomorphisms",
  "num_results": 20,
  "query_augmentation": true
}
```

**Parameters**:
- `query` (required): Natural language search query
- `num_results` (optional): Number of results (default: 10, max: 100)
- `query_augmentation` (optional): Enable query augmentation (default: true)

### Response

```json
{
  "results": [
    {
      "name": "RingHom.map_mul",
      "type": "forall {R S : Type*} ...",
      "module": "Mathlib.Algebra.Ring.Hom.Defs",
      "docstring": "A ring homomorphism preserves multiplication",
      "score": 0.95
    }
  ],
  "count": 1,
  "query": "theorems about ring homomorphisms"
}
```

## Best Practices

### Query Construction

1. **Use Natural Language**: Write queries as natural questions
2. **Be Specific**: Include key concepts and relationships
3. **Avoid Jargon**: Use common mathematical terms
4. **Keep Concise**: Queries under 100 characters work best

### Error Handling

1. **Always Timeout**: Set reasonable timeout (5s)
2. **Retry Once**: Retry failed requests once
3. **Use Fallbacks**: Have fallback chain ready (Loogle, local search)

## Comparison with Loogle

| Feature | LeanSearch | Loogle |
|---------|------------|--------|
| **Query Type** | Natural language | Type patterns |
| **Search Method** | Semantic (ML) | Syntactic (type matching) |
| **Best For** | Exploratory search | Precise type search |

## References

- [LeanSearch Website](https://leansearch.net/)
- [Mathlib Documentation](https://leanprover-community.github.io/mathlib4_docs/)
