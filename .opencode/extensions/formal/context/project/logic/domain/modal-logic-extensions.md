# Modal Logic Extensions

**Created**: 2026-02-27
**Purpose**: Extensions and variations of basic modal logic

---

## Basic Modal Systems

### System K

Minimal normal modal logic:
- **Axiom K**: Box(p -> q) -> (Box p -> Box q)
- **Rule N** (Necessitation): If |- p then |- Box p

### Common Extensions

| System | Additional Axioms | Frame Condition |
|--------|------------------|-----------------|
| K | - | - |
| T | Box p -> p | Reflexive |
| D | Box p -> Diamond p | Serial |
| K4 | Box p -> Box Box p | Transitive |
| S4 | T + K4 | Reflexive, transitive |
| S5 | S4 + Box p -> Diamond Box p | Equivalence relation |
| KB | K + p -> Box Diamond p | Symmetric |

## Multimodal Logics

### Syntax

Multiple modal operators: Box_1, Box_2, ... or [a], [b], ...

### Product Logics

L1 x L2 combines logics L1 and L2 with:
- Separate operators for each logic
- Commutativity: Box_1 Box_2 p <-> Box_2 Box_1 p

### Fusion Logics

L1 + L2 simply combines axioms without interaction.

## Epistemic Logic

### Knowledge Operator K_a

- K_a p: Agent a knows p
- Typical system: S5 for each agent

### Common Knowledge

C_G p: Common knowledge among group G
- Everyone knows, everyone knows everyone knows, ...

### Belief

B_a p: Agent a believes p
- Typically KD45

## Dynamic Logics

### Propositional Dynamic Logic (PDL)

- [alpha]p: After all executions of program alpha, p holds
- <alpha>p: After some execution, p holds

### Update Logic

[!phi]psi: After public announcement of phi, psi holds

## Conditional Logic

### Counterfactuals

phi > psi: If phi were true, psi would be true

### Selection Functions

f(w, phi) = closest phi-worlds to w

## Provability Logic

### GL (Goedel-Loeb)

- Box p -> Box Box p (K4)
- Box(Box p -> p) -> Box p (Loeb)

Interprets Box as provability in PA.

## Relevance to Logos

### Bimodal Logic

The Logos project uses bimodal logic with:
- Constitutive modality (structure)
- Dynamic modality (change)

### Interactions

- Cross-modal axioms
- Frame correspondences
- Completeness for product frames
