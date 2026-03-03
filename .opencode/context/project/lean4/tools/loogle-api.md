# Loogle CLI API Documentation

**Version**: Lean 4 (v4.27.0-rc1)  
**Last Updated**: 2025-12-27  
**Binary Location**: `/home/benjamin/.cache/loogle/.lake/build/bin/loogle`

---

## Overview

Loogle is a search tool for Lean 4 and Mathlib that enables searching for definitions, theorems, and lemmas by:
- Constant names (e.g., `Real.sin`)
- Lemma name substrings (e.g., `"differ"`)
- Type patterns (e.g., `?a → ?b → ?a ∧ ?b`)
- Conclusion patterns (e.g., `|- _ < _ → _`)

This document covers both the **CLI interface** (recommended for lean-research-agent) and the **Web API**.

---

## CLI Interface (Recommended)

### Quick Start

```bash
# Search by constant name
loogle --json "List.map"

# Search by name fragment
loogle --json '"replicate"'

# Search by type pattern
loogle --json "?a → ?b → ?a ∧ ?b"

# Search by conclusion
loogle --json "|- tsum _ = _ * tsum _"

# Combined search
loogle --json "Real.sin, tsum, _ * _"
```

### Interactive Mode (Best for Agents)

```bash
# Start interactive mode
loogle --json --interactive

# Wait for: "Loogle is ready.\n"
# Then send queries (one per line) and read JSON responses
```

### Command Syntax

```
loogle [OPTIONS] [QUERY]
```

### CLI Options

| Option | Short | Description |
|--------|-------|-------------|
| `--help` | - | Display help message |
| `--interactive` | `-i` | Read queries from stdin |
| `--json` | `-j` | Output JSON format |
| `--module mod` | - | Import module (default: Mathlib) |
| `--path path` | - | Custom .olean search path |
| `--write-index file` | - | Save index to file |
| `--read-index file` | - | Load index from file |

### JSON Output Format

#### Success Response

```json
{
  "header": "Found 5 declarations mentioning List.map. Of these, 3 match your pattern(s).",
  "heartbeats": 1234,
  "count": 3,
  "hits": [
    {
      "name": "List.map",
      "type": "∀ {α β : Type u_1}, (α → β) → List α → List β",
      "module": "Init.Data.List.Basic",
      "doc": "Map a function over a list. O(length as)"
    }
  ],
  "suggestions": []
}
```

**Fields**:
- `header` (string): Human-readable summary
- `heartbeats` (number): Performance metric (heartbeats / 1000)
- `count` (number): Total matching declarations
- `hits` (array): Matching declarations
  - `name` (string): Fully qualified name
  - `type` (string): Type signature
  - `module` (string | null): Module path
  - `doc` (string | null): Documentation
- `suggestions` (array, optional): Alternative queries

#### Error Response

```json
{
  "error": "Unknown identifier 'Foo'",
  "heartbeats": 123,
  "suggestions": ["\"Foo\"", "Bar.Foo"]
}
```

### Performance Characteristics

| Operation | Duration | Notes |
|-----------|----------|-------|
| Index build (first run) | 60-120s | Mathlib only |
| Index load (--read-index) | 5-10s | Pre-built index |
| Interactive startup | 5-180s | Depends on index |
| Simple query | 0.1-0.5s | After index ready |
| Complex query | 1-5s | Pattern matching |

### Integration Pattern (Python)

```python
import subprocess
import json

class LoogleClient:
    def __init__(self, binary_path, index_path=None, timeout=180):
        self.binary_path = binary_path
        self.process = None
        self.ready = False
        self.start(index_path, timeout)
    
    def start(self, index_path, timeout):
        """Start Loogle in interactive mode"""
        cmd = [self.binary_path, "--json", "--interactive"]
        if index_path:
            cmd.extend(["--read-index", index_path])
        
        self.process = subprocess.Popen(
            cmd,
            stdin=subprocess.PIPE,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
            bufsize=1
        )
        
        # Wait for "Loogle is ready.\n"
        import time
        start_time = time.time()
        while time.time() - start_time < timeout:
            line = self.process.stdout.readline()
            if line == "Loogle is ready.\n":
                self.ready = True
                return
            if self.process.poll() is not None:
                raise RuntimeError("Loogle process died during startup")
        
        raise TimeoutError("Loogle startup timed out")
    
    def query(self, query_string, timeout=10):
        """Execute a query and return parsed JSON"""
        if not self.ready:
            raise RuntimeError("Loogle not ready")
        
        # Send query
        self.process.stdin.write(query_string + "\n")
        self.process.stdin.flush()
        
        # Read response with timeout
        import select
        ready, _, _ = select.select([self.process.stdout], [], [], timeout)
        if not ready:
            raise TimeoutError(f"Query timed out: {query_string}")
        
        response_line = self.process.stdout.readline()
        return json.loads(response_line)
    
    def close(self):
        """Shutdown Loogle process"""
        if self.process:
            self.process.stdin.close()
            self.process.terminate()
            self.process.wait(timeout=5)

# Usage
loogle = LoogleClient(
    binary_path="/home/benjamin/.cache/loogle/.lake/build/bin/loogle",
    index_path="/tmp/loogle-mathlib.index",
    timeout=180
)

result = loogle.query("List.map", timeout=10)
loogle.close()
```

### Index Management

```bash
# Build index (one-time setup)
loogle --write-index ~/.cache/loogle-mathlib.index --module Mathlib

# Use index for fast startup
loogle --read-index ~/.cache/loogle-mathlib.index --json "List.map"
```

---

## Query Syntax

### 1. Search by Constant Name

**Syntax**: Unquoted identifier

**Example**: `Real.sin`

**Matches**: All declarations mentioning `Real.sin` in their type

```bash
loogle --json "Real.sin"
```

### 2. Search by Name Fragment

**Syntax**: Quoted string

**Example**: `"differ"`

**Matches**: Declarations with "differ" in name (case-insensitive, suffix matching)

```bash
loogle --json '"differ"'
loogle --json '"y_tru"'  # Matches "my_true"
```

### 3. Search by Type Pattern

**Syntax**: Term with metavariables (`_` or `?name`)

**Metavariables**:
- `_` - Anonymous (each independent)
- `?name` - Named (same name = same value)

**Examples**:

```bash
# Find multiplication with power
loogle --json "_ * (_ ^ _)"

# Find conjunction introduction
loogle --json "?a → ?b → ?a ∧ ?b"

# Non-linear pattern (same metavar twice)
loogle --json "Real.sqrt ?a * Real.sqrt ?a"

# Parameter order doesn't matter
loogle --json "(?a -> ?b) -> List ?a -> List ?b"  # Finds List.map
loogle --json "List ?a -> (?a -> ?b) -> List ?b"  # Also finds List.map
```

### 4. Search by Conclusion

**Syntax**: `⊢ pattern` or `|- pattern`

**Matches**: Only the conclusion (right of all `→` and `∀`)

**Constraint**: Pattern must be of type `Sort` (Prop, Type, etc.)

**Examples**:

```bash
# Conclusion with specific shape
loogle --json "|- tsum _ = _ * tsum _"

# Conclusion with hypothesis
loogle --json "|- _ < _ → tsum _ < tsum _"

# Hypothesis order doesn't matter
loogle --json "|- 0 < ?n → _ ≤ ?n"
```

### 5. Combined Filters

**Syntax**: Comma-separated filters

**Logic**: All filters must match (AND)

**Examples**:

```bash
# Multiple constants
loogle --json "Real.sin, tsum"

# Constant + name fragment
loogle --json 'List.map, "assoc"'

# Pattern + conclusion + name
loogle --json "Real.sin, \"two\", tsum, _ * _, |- _ < _ → _"
```

---

## Query Examples by Domain

### Modal Logic

```bash
# Necessitation
loogle --json "□ _ → □ _"

# K axiom
loogle --json "□ (_ → _) → □ _ → □ _"

# T axiom (reflexivity)
loogle --json "□ _ → _"

# 4 axiom (transitivity)
loogle --json "□ _ → □ □ _"

# S5 axiom
loogle --json "◇ _ → □ ◇ _"
```

### Temporal Logic

```bash
# Until operator
loogle --json "Until _ _"

# Eventually
loogle --json "Eventually _"

# Always
loogle --json "Always _"

# Temporal properties
loogle --json "Always _ → Eventually _"
```

### List Operations

```bash
# List map
loogle --json "List.map"
loogle --json "(?a -> ?b) -> List ?a -> List ?b"

# List append
loogle --json "List.append"
loogle --json "List ?a → List ?a → List ?a"

# List replicate
loogle --json "List.replicate"
loogle --json '"replicate"'
```

---

## Error Handling

### Common Errors

| Error Message | Cause | Solution |
|---------------|-------|----------|
| `Cannot search: No constants...` | Empty query | Add search terms |
| `Unknown identifier 'X'` | Unresolved name | Use quoted string or qualified name |
| `Name pattern is too general` | Pattern too short | Use longer pattern (>1 char) |
| `Conclusion pattern is of type Bool...` | Wrong type | Use Sort-typed pattern |

### Error Recovery

```python
def query_with_retry(loogle, query):
    result = loogle.query(query)
    
    if "error" in result:
        # Try suggestions
        if "suggestions" in result and result["suggestions"]:
            return loogle.query(result["suggestions"][0])
        
        # Fallback to web search
        return web_search(query)
    
    return result
```

---

## Web API (Alternative)

### HTTP Request

```http
GET https://loogle.lean-lang.org/json?q={query}
```

**Parameters**:
- `q` (required): URL-encoded query string

**Headers**:
```http
Accept: application/json
User-Agent: LEAN4-Logos/Theory/1.0
```

### HTTP Response

Same JSON format as CLI `--json` output.

---

## Best Practices

### 1. Use Index Persistence

```bash
# Build once
loogle --write-index ~/.cache/loogle.index --module Mathlib

# Use many times
loogle --read-index ~/.cache/loogle.index --json "query"
```

### 2. Use Interactive Mode for Agents

```python
# Start once at agent initialization
loogle = LoogleClient(binary_path, index_path, timeout=180)

# Query many times
result1 = loogle.query("List.map")
result2 = loogle.query("?a → ?b")
result3 = loogle.query('"replicate"')

# Cleanup at shutdown
loogle.close()
```

### 3. Implement Timeouts

```python
# Always use timeouts
result = loogle.query(query, timeout=10)

# Monitor query duration
import time
start = time.time()
result = loogle.query(query)
duration = time.time() - start
if duration > 10:
    logger.warning(f"Slow query: {query} ({duration:.2f}s)")
```

### 4. Cache Results

```python
import functools

@functools.lru_cache(maxsize=1000)
def cached_loogle_query(query):
    return loogle.query(query, timeout=10)
```

### 5. Graceful Degradation

```python
def search_with_fallback(query):
    try:
        # Try Loogle CLI first
        return loogle.query(query, timeout=10)
    except (TimeoutError, subprocess.SubprocessError):
        # Fallback to web API
        logger.warning("Loogle CLI failed, trying web API")
        return loogle_web_api(query)
    except Exception:
        # Fallback to web search
        logger.warning("Loogle unavailable, using web search")
        return web_search(query)
```

---

## Security Notes

### Index File Trust

**Warning**: Index files are blindly trusted by Loogle.

**Best Practices**:
- Only use self-built index files
- Store in secure location (e.g., `~/.cache/`)
- Set restrictive permissions (chmod 600)
- Validate integrity with checksums

### Query Sanitization

```python
def sanitize_query(query):
    # Remove control characters
    query = ''.join(c for c in query if c.isprintable())
    
    # Limit length
    if len(query) > 500:
        query = query[:500]
    
    return query
```

---

## Troubleshooting

### Issue: Loogle Times Out

**Cause**: Index not built or corrupted

**Solution**:
```bash
# Rebuild index
loogle --write-index /tmp/loogle.index --module Mathlib
```

### Issue: Process Dies During Startup

**Cause**: Out of memory

**Solution**:
- Increase system memory
- Use pre-built index
- Reduce concurrent processes

### Issue: Invalid JSON Output

**Cause**: Process crash or output corruption

**Solution**:
```python
try:
    result = json.loads(output)
except json.JSONDecodeError:
    # Restart process
    loogle.restart()
```

---

## References

- **Loogle GitHub**: https://github.com/nomeata/loogle
- **Loogle Web**: https://loogle.lean-lang.org/
- **Lean 4 Docs**: https://leanprover.github.io/
- **Mathlib Docs**: https://leanprover-community.github.io/mathlib4_docs/
- **CLI Source**: `/home/benjamin/.cache/loogle/Loogle.lean`
- **Find Module**: `/home/benjamin/.cache/loogle/Loogle/Find.lean`

---

## Changelog

### 2025-12-27
- Added comprehensive CLI interface documentation
- Added interactive mode integration pattern
- Added JSON format specification
- Added performance characteristics
- Added error handling guide
- Added security notes
- Reorganized for CLI-first approach

### 2025-12-16
- Initial web API documentation
