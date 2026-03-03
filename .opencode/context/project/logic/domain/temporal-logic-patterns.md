# Temporal Logic Patterns

**Created**: 2026-02-27
**Purpose**: Temporal logic constructs for reasoning about time

---

## Linear Temporal Logic (LTL)

### Basic Operators

| Operator | Reading | Meaning |
|----------|---------|---------|
| X phi | Next phi | phi holds at next moment |
| F phi | Eventually phi | phi holds sometime in future |
| G phi | Always phi | phi holds at all future moments |
| phi U psi | phi Until psi | phi holds until psi becomes true |

### Relationships

- F phi = true U phi
- G phi = not F (not phi)
- G phi = phi and X G phi

### Frame: Linear Order

(T, <) where < is strict linear order
- Discrete: (N, <)
- Dense: (Q, <)
- Continuous: (R, <)

## Computation Tree Logic (CTL)

### Path Quantifiers

- A: For all paths
- E: For some path

### Combined Operators

| CTL | Meaning |
|-----|---------|
| AG phi | On all paths, always phi |
| EF phi | On some path, eventually phi |
| AF phi | On all paths, eventually phi |
| EG phi | On some path, always phi |
| A[phi U psi] | On all paths, phi until psi |
| E[phi U psi] | On some path, phi until psi |

## CTL*

Combines LTL and CTL:
- Path formulas: LTL operators
- State formulas: Path quantifiers + path formulas

## Past Operators

### Mirror of Future

| Past | Future | Meaning |
|------|--------|---------|
| Y | X | Yesterday/Previous |
| P | F | Past/Eventually before |
| H | G | Historically/Always before |
| S | U | Since |

### Kamp's Theorem

LTL with Until and Since is expressively complete for first-order logic over (R, <).

## Interval Temporal Logic

### Allen's Relations

13 relations between intervals:
- Before, meets, overlaps, starts, during, finishes, equals
- Plus inverses

### Duration Calculus

Integrates values over intervals.

## Real-Time Extensions

### Metric Temporal Logic (MTL)

- F_{[a,b]} phi: phi within time interval [a,b]
- G_{[0,10]} phi: phi for next 10 time units

### Timed Automata

Automata with clocks and clock constraints.

## Relevance to Logos

### Perpetuity Modality

The dynamic modality in Logos includes temporal aspects:
- Task persistence over time
- Obligation fulfillment deadlines

### Pattern: Liveness

G(request -> F response)
"Every request is eventually answered"

### Pattern: Safety

G(not bad_state)
"Bad states are never reached"

### Pattern: Fairness

G F action
"Action occurs infinitely often"
