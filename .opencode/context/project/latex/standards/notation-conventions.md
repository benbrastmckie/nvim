# Notation Conventions

## logos-notation.sty Overview

The `logos-notation.sty` package provides consistent notation for Logos documentation. Always use these macros rather than raw LaTeX symbols.

## Constitutive Foundation Notation

### State Space
| Concept | Macro | Output | Usage |
|---------|-------|--------|-------|
| State space | `\statespace` | S | Set of states |
| Null state | `\nullstate` | □ | Bottom element |
| Full state | `\fullstate` | ■ | Top element |
| Fusion | `\fusion{s}{t}` | s · t | Least upper bound |
| Parthood | `\parthood` | ⊑ | Partial order |

### Verification/Falsification
| Concept | Macro | Output | Usage |
|---------|-------|--------|-------|
| Verifies | `\verifies` | ⊩⁺ | State verifies formula |
| Falsifies | `\falsifies` | ⊩⁻ | State falsifies formula |
| Verifier set | `\verifierset{F}` | v_F | Verifier functions |
| Falsifier set | `\falsifierset{F}` | f_F | Falsifier functions |

### Propositional Operations
| Concept | Macro | Output | Usage |
|---------|-------|--------|-------|
| Product | `\product` | ⊗ | Verifier/falsifier product |
| Sum | `\psum` | ⊕ | Verifier/falsifier sum |
| Propositional identity | `\propid` | ≡ | Same bilateral proposition |

### Derived Relations
| Concept | Macro | Output | Usage |
|---------|-------|--------|-------|
| Essence | `\essence` | ⊑ | A essential to B |
| Ground | `\ground` | ≤ | A grounds B |

## Core Extension Notation

### Variable Assignment
| Concept | Macro | Output | Usage |
|---------|-------|--------|-------|
| Assignment | `\assignment` | σ | Variable assignment |
| Substitution | `\assignsub{v}{x}` | σ[v/x] | Assignment update |
| Semantic brackets | `\sem{t}` | ⟦t⟧ | Term extension |

### Temporal Order
| Concept | Macro | Output | Usage |
|---------|-------|--------|-------|
| Temporal order | `\temporalorder` | D | Time structure |
| Time less than | `\timelt` | < | Strict ordering |
| Time less/equal | `\timeleq` | ≤ | Non-strict ordering |

### Task Relation
| Concept | Macro | Output | Usage |
|---------|-------|--------|-------|
| Task relation | `\taskrel` | ⇒ | Task operator |
| Task | `\task{s}{d}{t}` | s ⇒_d t | Task from s to t |

### State Modality
| Concept | Macro | Output | Usage |
|---------|-------|--------|-------|
| Possible states | `\possible` | P | Possible state set |
| Compatible | `\compatible` | ∘ | State compatibility |
| Connected | `\connected` | ~ | State connection |
| World-states | `\worldstates` | W | Maximal possible states |
| Necessary states | `\necessary` | N | Necessary state set |
| Max compatible | `\maxcompat{s}{t}` | s_t | Maximal t-compatible parts |

### World-History
| Concept | Macro | Output | Usage |
|---------|-------|--------|-------|
| History | `\history` | τ | World-history function |
| History space | `\historyspace` | H_F | All world-histories |
| Temporal index | `\tempindex` | ⃗ı | Stored times vector |

### Truth Evaluation
| Concept | Macro | Output | Usage |
|---------|-------|--------|-------|
| Satisfies | `\satisfies` | ⊨ | Truth at context |
| Not satisfies | `\notsatisfies` | ⊭ | False at context |

### Modal Operators
| Concept | Macro | Output | Usage |
|---------|-------|--------|-------|
| Necessity | `\nec` | □ | Necessarily |
| Possibility | `\poss` | ◇ | Possibly |

### Temporal Operators
| Concept | Macro | Output | Usage |
|---------|-------|--------|-------|
| Always past | `\always` | H | It has always been |
| Always future | `\willalways` | G | It will always be |
| Some past | `\waspast` | P | It was the case |
| Some future | `\willfuture` | F | It will be the case |
| Always (derived) | `\alwaystemporal` | △ | At all times |
| Sometimes (derived) | `\sometimestemporal` | ▽ | At some time |

### Extended Temporal
| Concept | Macro | Output | Usage |
|---------|-------|--------|-------|
| Since | `\since` | ◁ | A since B |
| Until | `\until` | ▷ | A until B |

### Counterfactual
| Concept | Macro | Output | Usage |
|---------|-------|--------|-------|
| Would-counterfactual | `\boxright` | □→ | If...would |
| Imposition | `\imposition{t}{w}` | t →_w | Imposing t on w |

### Store/Recall
| Concept | Macro | Output | Usage |
|---------|-------|--------|-------|
| Store | `\store{i}` | ↑ⁱ | Store current time |
| Recall | `\recall{i}` | ↓ⁱ | Recall stored time |

### Actuality
| Concept | Macro | Output | Usage |
|---------|-------|--------|-------|
| Actuality predicate | `\actual` | Act | Part of current world |

## Model Notation

| Concept | Macro | Output | Usage |
|---------|-------|--------|-------|
| Frame | `\frame` | **F** | Semantic frame |
| Model | `\model` | **M** | Semantic model |
| Interpretation | `\interp` | I | Interpretation function |

## Meta-Variables

| Concept | Macro | Output | Usage |
|---------|-------|--------|-------|
| Formula A | `\metaA` | A | Meta-variable for formulas |
| Formula B | `\metaB` | B | Meta-variable for formulas |
| Formula φ | `\metaphi` | φ | Greek meta-variable |
| Formula ψ | `\metapsi` | ψ | Greek meta-variable |

## Lean Cross-References

| Concept | Macro | Usage |
|---------|-------|-------|
| Lean source | `\leansrc{Module}{def}` | Reference to Lean definition |
| Lean ref | `\leanref{path}` | Reference to Lean file |

### Example
```latex
See \leansrc{Logos.Foundation.Frame}{ConstitutiveFrame} for the Lean implementation.
```

## Usage Guidelines

1. **Always use macros**: Never type `\Box` directly; use `\nec` instead
2. **Consistent spacing**: Macros handle spacing automatically
3. **Semantic meaning**: Choose macros by meaning, not appearance
4. **Cross-references**: Always link to Lean implementations when available
