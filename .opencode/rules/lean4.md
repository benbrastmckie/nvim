---
paths: "**/*.lean"
---

# Lean 4 Development Rules

## MCP Tools (lean-lsp server)

### Essential Tools

| Tool | Purpose | Use When |
|------|---------|----------|
| `lean_goal` | Proof state at position | MOST IMPORTANT - use constantly while proving |
| `lean_hover_info` | Type signatures + docs | Understanding APIs and types |
| `lean_completions` | IDE autocomplete | On incomplete code after `.` or partial name |
| `lean_local_search` | Fast local declaration search | BEFORE trying a lemma name |

### Search Tools (Rate Limited)

| Tool | Rate | Purpose | Query Style |
|------|------|---------|-------------|
| `lean_leansearch` | 3/30s | Natural language → Mathlib | "sum of two even numbers is even" |
| `lean_loogle` | 3/30s | Type pattern search | `(?a → ?b) → List ?a → List ?b` |
| `lean_leanfinder` | 10/30s | Semantic concept search | "commutativity of addition" |
| `lean_state_search` | 3/30s | Goal → closing lemmas | At goal position |
| `lean_hammer_premise` | 3/30s | Goal → simp/aesop hints | At goal position |

### Search Decision Tree

```
1. "Does X exist locally?"
   → lean_local_search

2. "I need a lemma that says X"
   → lean_leansearch (natural language)

3. "Find lemma matching this type"
   → lean_loogle (type pattern)

4. "What's the Lean name for concept X?"
   → lean_leanfinder (semantic)

5. "What closes this goal?"
   → lean_state_search (at position)

6. "What should I feed simp?"
   → lean_hammer_premise (at position)
```

### Workflow Pattern

```
1. After finding a name:
   lean_local_search → verify it exists
   lean_hover_info → get full signature

2. During proof development:
   lean_goal (constantly) → see proof state
   lean_multi_attempt → test tactics ["simp", "ring", "omega"]
   lake build → check for errors

3. After editing:
   lake build → verify no errors
   lean_goal → confirm proof progress
```

## Code Patterns

### Module Structure
```lean
import Mathlib.Tactic
import Logos.Shared.Definitions

namespace Logos.Layer0

-- Definitions first
def MyDef : Type := ...

-- Theorems after
theorem my_theorem : ... := by
  ...

end Logos.Layer0
```

### Proof Style
- Prefer tactic proofs over term proofs for complex theorems
- Use `by` blocks for tactics
- Keep proofs readable with appropriate whitespace
- Document non-obvious steps with comments

### Common Tactics
```lean
-- Automation
simp [lemma1, lemma2]    -- Simplification
aesop                     -- Automated reasoning
omega                     -- Linear arithmetic
ring                      -- Ring equations
decide                    -- Decidable propositions

-- Structure
intro h                   -- Introduce hypothesis
apply lemma              -- Apply lemma
exact h                  -- Exact match
constructor              -- Split goal
cases h with             -- Case analysis
induction n with         -- Induction

-- Rewriting
rw [lemma]               -- Rewrite with lemma
simp only [lemma]        -- Controlled simp
conv => ...              -- Conversion mode
```

## Error Handling

### Common Errors

| Error | Cause | Fix |
|-------|------|-----|
| "unknown identifier" | Missing import or typo | Check imports, use lean_local_search |
| "type mismatch" | Wrong type | Use lean_hover_info to check types |
| "failed to synthesize" | Missing instance | Add instance or import |
| "unsolved goals" | Incomplete proof | Use lean_goal to see remaining |

### Debugging Steps
1. Run `lake build` to see all errors
2. Use `lean_goal` at error location
3. Use `lean_hover_info` on problematic terms
4. Search for relevant lemmas with lean_leansearch

## Project-Specific

### Layer Structure
```
Layer0: Classical propositional logic
Layer1: Modal logic (box, diamond operators)
Layer2: Temporal logic (always, eventually)
Layer3+: Epistemic, deontic extensions
```

### Shared Definitions
Common types and definitions in `Logos/Shared/`:
- `Frame` - Kripke frame structure
- `Model` - Semantic model
- `Valuation` - Propositional valuation
- `Satisfaction` - Satisfaction relation

### Import Patterns
```lean
-- For Layer0 work
import Logos.Layer0.Syntax
import Logos.Layer0.Semantics

-- For Layer1 work (includes Layer0)
import Logos.Layer1.Syntax
import Logos.Layer1.Semantics
```

## Build Commands

```bash
# Build project
lake build

# Build specific module
lake build Logos.Layer0.Syntax

# Clean and rebuild
lake clean && lake build
```

## Testing

After implementation:
1. Run `lake build` to check compilation
2. Use `lean_goal` to verify no errors
3. Check that all theorems compile without `sorry`
