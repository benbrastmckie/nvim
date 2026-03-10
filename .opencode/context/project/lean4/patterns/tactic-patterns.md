# Lean 4 Tactic Patterns

## Automation Tactics

### simp
Simplification using simp lemmas.
```lean
simp only [lemma1, lemma2]  -- Specific lemmas
simp [*]                     -- Include local hypotheses
simp_all                     -- Simplify everything
```

### omega
Linear arithmetic over integers and naturals.
```lean
omega  -- Closes goals like `n + m = m + n` for Nat/Int
```

### ring
Polynomial arithmetic.
```lean
ring  -- Closes `a * b + c * d = c * d + a * b`
```

### decide
Decidable propositions.
```lean
decide  -- For Bool, Nat comparisons, etc.
```

### aesop
Automated proof search.
```lean
aesop  -- General automation, uses registered rules
```

## Structural Tactics

### intro
Introduce assumptions/arguments.
```lean
intro h      -- Single assumption
intro h1 h2  -- Multiple
intro        -- Let Lean name it
```

### apply
Apply a lemma or function.
```lean
apply lemma        -- Apply lemma, create subgoals
apply Nat.le_succ  -- Specific lemma
```

### exact
Provide exact term.
```lean
exact h      -- Exact hypothesis
exact rfl    -- Reflexivity
exact ⟨a, b⟩  -- Construct pair
```

### constructor
Split conjunctions/existentials.
```lean
constructor  -- For ∧, ∃, structures
```

### cases
Case analysis.
```lean
cases h with | left hl => ... | right hr => ...
cases h  -- Auto-generated names
```

### induction
Inductive proofs.
```lean
induction n with | zero => ... | succ n ih => ...
```

## Rewriting

### rw
Rewrite using equalities.
```lean
rw [h]       -- Apply equality h
rw [←h]      -- Backwards
rw [h1, h2]  -- Multiple
```

### conv
Targeted rewriting.
```lean
conv => lhs; rw [h]   -- Rewrite only left side
conv => rhs; simp     -- Simplify only right side
```

## Common Patterns

### Goal: `P ∧ Q`
```lean
constructor
· -- prove P
· -- prove Q
```

### Goal: `∃ x, P x`
```lean
use witness
-- prove P witness
```

### Goal: `P ∨ Q`
```lean
left   -- reduce to P
right  -- reduce to Q
```

### Goal: `P → Q`
```lean
intro hp
-- prove Q using hp : P
```

### Hypothesis: `h : P ∧ Q`
```lean
obtain ⟨hp, hq⟩ := h
-- now have hp : P and hq : Q
```

### Hypothesis: `h : P ∨ Q`
```lean
cases h with
| inl hp => -- use hp : P
| inr hq => -- use hq : Q
```

## Tool Integration

### lean_multi_attempt
Try multiple tactics efficiently:
```lean
lean_multi_attempt with snippets: ["simp", "ring", "omega", "aesop", "decide"]
```

### lean_state_search
When stuck, search for closing lemmas.

### lean_hammer_premise
Get hints for simp arguments.
