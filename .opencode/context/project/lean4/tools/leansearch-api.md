# LeanSearch API Integration Guide

**Purpose**: Guide for integrating with LeanSearch semantic search API

**Last Updated**: December 16, 2025

---

## Overview

LeanSearch is a semantic search engine for LEAN libraries using natural language queries. It uses machine learning to find relevant theorems and definitions based on conceptual similarity rather than exact type matching.

**API Endpoint**: `https://leansearch.net/api/search`

---

## Query Types

### Natural Language Queries

LeanSearch excels at natural language queries:

```
Query: "theorems about ring homomorphisms preserving multiplication"
Example Results:
  - RingHom.map_mul : f (x * y) = f x * f y
  - RingHom.map_pow : f (x ^ n) = f x ^ n
  - MonoidHom.map_mul : f (x * y) = f x * f y
```

```
Query: "continuous functions on real numbers"
Example Results:
  - continuous_sin : Continuous Real.sin
  - continuous_exp : Continuous Real.exp
  - Continuous.add : Continuous f → Continuous g → Continuous (f + g)
```

```
Query: "list concatenation is associative"
Example Results:
  - List.append_assoc : (l₁ ++ l₂) ++ l₃ = l₁ ++ (l₂ ++ l₃)
  - Array.append_assoc : (a₁ ++ a₂) ++ a₃ = a₁ ++ (a₂ ++ a₃)
```

---

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
- `num_results` (optional): Number of results to return (default: 10, max: 100)
- `query_augmentation` (optional): Enable query augmentation for better recall (default: true)

**Headers**:
```http
Content-Type: application/json
Accept: application/json
User-Agent: LEAN4-Logos/Theory/1.0
```

### HTTP Response

**Success (200 OK)**:
```json
{
  "results": [
    {
      "name": "RingHom.map_mul",
      "type": "∀ {R S : Type*} [Ring R] [Ring S] (f : R →+* S) (x y : R), f (x * y) = f x * f y",
      "module": "Mathlib.Algebra.Ring.Hom.Defs",
      "docstring": "A ring homomorphism preserves multiplication",
      "score": 0.95
    },
    {
      "name": "RingHom.map_one",
      "type": "∀ {R S : Type*} [Ring R] [Ring S] (f : R →+* S), f 1 = 1",
      "module": "Mathlib.Algebra.Ring.Hom.Defs",
      "docstring": "A ring homomorphism preserves the multiplicative identity",
      "score": 0.87
    }
  ],
  "count": 2,
  "query": "theorems about ring homomorphisms",
  "augmented_query": "ring homomorphism multiplication preservation morphism"
}
```

**Error (4xx/5xx)**:
```json
{
  "error": "Query too long",
  "code": "QUERY_TOO_LONG",
  "details": "Query must be less than 500 characters"
}
```

---

## Integration Pattern

### Request Function

```yaml
leansearch_search:
  inputs:
    query: string
    num_results: integer (default: 20)
    query_augmentation: boolean (default: true)
    timeout: duration (default: 5s)
    retry: boolean (default: true)
    
  process:
    1. Validate query length (< 500 chars)
    2. Construct request body
    3. Send POST request with timeout
    4. Parse JSON response
    5. Normalize results
    6. Return structured data
    
  error_handling:
    timeout: "Retry once, then return cached or empty"
    4xx_error: "Log and return empty results"
    5xx_error: "Retry once, then return cached or empty"
    network_error: "Return cached results or empty"
    
  output:
    status: enum ["success", "partial", "cached", "error"]
    results: array[LeanSearchResult]
    metadata:
      query: string
      augmented_query: string
      search_time_ms: integer
      source: enum ["lean_search", "cache"]
```

### Result Normalization

```yaml
normalize_result:
  input: raw_leansearch_result
  
  process:
    1. Extract name, type, module, docstring, score
    2. Parse type signature
    3. Extract type components
    4. Generate usage example
    5. Normalize score to [0.0, 1.0]
    
  output:
    name: string
    type: string
    type_components:
      parameters: array[string]
      conclusion: string
    module: string
    docstring: string
    usage_example: string
    relevance_score: float [0.0, 1.0]
    source: "lean_search"
```

---

## Caching Strategy

### Cache Key

```yaml
cache_key:
  format: "leansearch:{query_hash}:{num_results}"
  example: "leansearch:abc123:20"
```

### Cache Entry

```yaml
cache_entry:
  key: string
  query: string
  num_results: integer
  results: array[LeanSearchResult]
  augmented_query: string
  timestamp: datetime
  ttl: 1h
  access_count: integer
```

### Cache Policy

```yaml
caching:
  ttl: 1h  # Shorter than Loogle due to ML model updates
  max_entries: 200
  eviction: "LRU"
  invalidation:
    - Manual invalidation
    - Model update
    - TTL expiration
```

---

## Error Handling

### Error Types

```yaml
errors:
  timeout:
    http_code: null
    action: "Retry once with same timeout"
    fallback: "Use cached results or return empty"
    
  query_too_long:
    http_code: 400
    action: "Truncate query and retry"
    fallback: "Use Loogle instead"
    
  service_unavailable:
    http_code: 503
    action: "Return cached results"
    fallback: "Use Loogle or local search"
    
  rate_limited:
    http_code: 429
    action: "Wait and retry with backoff"
    fallback: "Use cached results"
    
  network_error:
    http_code: null
    action: "Retry once"
    fallback: "Use cached results or Loogle"
```

### Fallback Chain

```yaml
fallback_chain:
  1. Try LeanSearch API
  2. If fails, check cache
  3. If no cache, try Loogle
  4. If fails, use local search
  5. If fails, return empty with error
```

---

## Query Optimization

### Query Preprocessing

```yaml
preprocessing:
  lowercase:
    before: "Ring Homomorphisms"
    after: "ring homomorphisms"
    
  remove_punctuation:
    before: "What are ring homomorphisms?"
    after: "what are ring homomorphisms"
    
  trim_whitespace:
    before: "  ring homomorphisms  "
    after: "ring homomorphisms"
    
  truncate_long:
    before: "very long query..." (> 500 chars)
    after: "very long query..." (truncated to 500)
```

### Query Augmentation

```yaml
augmentation:
  enabled: true
  
  synonyms:
    "addition": ["sum", "plus", "add"]
    "multiplication": ["product", "times", "multiply"]
    "continuous": ["continuity", "continuous function"]
    
  related_terms:
    "ring": ["algebra", "monoid", "group"]
    "homomorphism": ["morphism", "map", "function"]
    
  expansion:
    "ring homomorphism": "ring homomorphism morphism map preserving structure"
```

---

## Performance Optimization

### Request Batching

```yaml
batching:
  strategy: "Batch multiple queries"
  batch_size: 3
  batch_timeout: 200ms
  implementation:
    - Collect queries for 200ms
    - Send all queries in parallel
    - Combine results
```

### Result Ranking

```yaml
ranking:
  factors:
    semantic_score:
      weight: 0.6
      source: "LeanSearch ML model"
      
    name_similarity:
      weight: 0.2
      method: "Fuzzy string matching"
      
    module_relevance:
      weight: 0.1
      method: "Module popularity"
      
    docstring_match:
      weight: 0.1
      method: "Keyword matching"
      
  formula: "weighted_sum(factors)"
```

### Result Deduplication

```yaml
deduplication:
  strategy: "Remove duplicates from multiple sources"
  
  process:
    1. Collect results from LeanSearch and Loogle
    2. Group by theorem name
    3. Keep highest scoring result
    4. Merge metadata
    
  example:
    input:
      - {name: "RingHom.map_mul", score: 0.95, source: "lean_search"}
      - {name: "RingHom.map_mul", score: 0.85, source: "loogle"}
    output:
      - {name: "RingHom.map_mul", score: 0.95, sources: ["lean_search", "loogle"]}
```

---

## Best Practices

### Query Construction

1. **Use Natural Language**: Write queries as natural questions or descriptions
2. **Be Specific**: Include key concepts and relationships
3. **Avoid Jargon**: Use common mathematical terms
4. **Keep Concise**: Queries under 100 characters work best

### Caching

1. **Cache Aggressively**: Cache all successful queries
2. **Shorter TTL**: Use 1h TTL due to model updates
3. **Invalidate on Update**: Invalidate when model updates
4. **Monitor Hit Rate**: Track and optimize cache hit rate

### Error Handling

1. **Always Timeout**: Set reasonable timeout (5s)
2. **Retry Once**: Retry failed requests once
3. **Use Fallbacks**: Have fallback chain ready (Loogle, local)
4. **Log Errors**: Log all errors for monitoring

### Performance

1. **Batch Queries**: Batch multiple queries when possible
2. **Parallel Requests**: Send multiple queries in parallel
3. **Limit Results**: Request only needed number of results
4. **Deduplicate**: Remove duplicates from multiple sources

---

## Comparison with Loogle

| Feature | LeanSearch | Loogle |
|---------|------------|--------|
| **Query Type** | Natural language | Type patterns |
| **Search Method** | Semantic (ML) | Syntactic (type matching) |
| **Precision** | Medium-High | High |
| **Recall** | High | Medium |
| **Speed** | Slower (5s) | Faster (3s) |
| **Cache TTL** | 1 hour | 24 hours |
| **Best For** | Exploratory search | Precise type search |

### When to Use Each

**Use LeanSearch**:
- Natural language queries
- Exploratory search
- Conceptual similarity
- Broad recall needed

**Use Loogle**:
- Type pattern queries
- Precise type matching
- Known type structure
- High precision needed

**Use Both**:
- Comprehensive search
- Combine semantic and syntactic
- Merge and deduplicate results
- Best of both worlds

---

## Example Queries

### Find Theorems About Continuity

```
Query: "continuous functions preserve limits"
Results:
  - Continuous.tendsto : Continuous f → Tendsto x l → Tendsto (f ∘ x) (map f l)
  - ContinuousAt.comp : ContinuousAt f (g x) → ContinuousAt g x → ContinuousAt (f ∘ g) x
```

### Find Theorems About List Operations

```
Query: "list map distributes over append"
Results:
  - List.map_append : (l₁ ++ l₂).map f = l₁.map f ++ l₂.map f
  - List.map_map : (l.map f).map g = l.map (g ∘ f)
```

### Find Theorems About Inequalities

```
Query: "if a is less than b then a plus c is less than b plus c"
Results:
  - add_lt_add_right : a < b → a + c < b + c
  - add_lt_add_left : a < b → c + a < c + b
```

---

## Integration Checklist

- [ ] Implement HTTP POST request with timeout
- [ ] Parse JSON response correctly
- [ ] Normalize results to standard format
- [ ] Implement caching with 1h TTL
- [ ] Handle all error types gracefully
- [ ] Implement fallback chain (Loogle, local)
- [ ] Add query preprocessing (lowercase, trim, truncate)
- [ ] Enable query augmentation
- [ ] Add result ranking
- [ ] Add result deduplication (with Loogle)
- [ ] Test with various natural language queries
- [ ] Test with service unavailable
- [ ] Test with timeout
- [ ] Measure and optimize cache hit rate
- [ ] Monitor API usage and rate limits

---

## References

- [LeanSearch Website](https://leansearch.net/)
- [LeanSearch Paper](https://arxiv.org/abs/2312.09773)
- [Mathlib Documentation](https://leanprover-community.github.io/mathlib4_docs/)
