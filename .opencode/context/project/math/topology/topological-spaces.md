# Topological Spaces in LEAN 4

## Overview
Topological spaces are fundamental structures in analysis and geometry. Mathlib4 provides a comprehensive framework for point-set topology, metric spaces, and topological properties.

## Core Definitions

### Topological Space
```lean
import Mathlib.Topology.Basic

class TopologicalSpace (X : Type*) where
  IsOpen : Set X → Prop
  isOpen_univ : IsOpen univ
  isOpen_inter : ∀ s t, IsOpen s → IsOpen t → IsOpen (s ∩ t)
  isOpen_sUnion : ∀ s, (∀ t ∈ s, IsOpen t) → IsOpen (⋃₀ s)
```

### Closed Sets
```lean
def IsClosed {X : Type*} [TopologicalSpace X] (s : Set X) : Prop :=
  IsOpen sᶜ

-- Complement of open is closed
theorem isClosed_compl_iff {X : Type*} [TopologicalSpace X] (s : Set X) :
    IsClosed s ↔ IsOpen sᶜ
```

### Neighborhoods
```lean
-- Neighborhood of a point
def nhds {X : Type*} [TopologicalSpace X] (x : X) : Filter X :=
  ⨅ s ∈ {s : Set X | x ∈ s ∧ IsOpen s}, 𝓟 s

-- s is a neighborhood of x
def IsNeighborhood {X : Type*} [TopologicalSpace X] (s : Set X) (x : X) : Prop :=
  s ∈ nhds x
```

### Continuity
```lean
-- Continuous function
def Continuous {X Y : Type*} [TopologicalSpace X] [TopologicalSpace Y] 
    (f : X → Y) : Prop :=
  ∀ s, IsOpen s → IsOpen (f ⁻¹' s)

-- Alternative characterization
theorem continuous_def {X Y : Type*} [TopologicalSpace X] [TopologicalSpace Y] 
    (f : X → Y) :
    Continuous f ↔ ∀ x, Tendsto f (nhds x) (nhds (f x))
```

## Key Theorems

### Open and Closed Sets
```lean
-- Empty set is open
theorem isOpen_empty {X : Type*} [TopologicalSpace X] : IsOpen (∅ : Set X)

-- Finite intersection of open sets is open
theorem isOpen_inter_of_finite {X : Type*} [TopologicalSpace X] 
    {s : Set (Set X)} (hs : s.Finite) (h : ∀ t ∈ s, IsOpen t) :
    IsOpen (⋂₀ s)

-- Arbitrary union of open sets is open
theorem isOpen_sUnion {X : Type*} [TopologicalSpace X] 
    {s : Set (Set X)} (h : ∀ t ∈ s, IsOpen t) :
    IsOpen (⋃₀ s)

-- Closed set properties
theorem isClosed_empty {X : Type*} [TopologicalSpace X] : IsClosed (∅ : Set X)
theorem isClosed_univ {X : Type*} [TopologicalSpace X] : IsClosed (univ : Set X)
theorem isClosed_union {X : Type*} [TopologicalSpace X] {s t : Set X}
    (hs : IsClosed s) (ht : IsClosed t) : IsClosed (s ∪ t)
```

### Continuity Theorems
```lean
-- Identity is continuous
theorem continuous_id {X : Type*} [TopologicalSpace X] : 
    Continuous (id : X → X)

-- Composition of continuous functions
theorem Continuous.comp {X Y Z : Type*} [TopologicalSpace X] 
    [TopologicalSpace Y] [TopologicalSpace Z]
    {g : Y → Z} {f : X → Y} (hg : Continuous g) (hf : Continuous f) :
    Continuous (g ∘ f)

-- Constant function is continuous
theorem continuous_const {X Y : Type*} [TopologicalSpace X] 
    [TopologicalSpace Y] (y : Y) :
    Continuous (fun _ : X => y)
```

## Metric Spaces

### Definition
```lean
import Mathlib.Topology.MetricSpace.Basic

class MetricSpace (X : Type*) extends PseudoMetricSpace X where
  eq_of_dist_eq_zero : ∀ {x y : X}, dist x y = 0 → x = y

-- Distance function
def dist {X : Type*} [MetricSpace X] : X → X → ℝ := 
  MetricSpace.dist

-- Metric space axioms
axiom dist_self {X : Type*} [MetricSpace X] (x : X) : dist x x = 0
axiom dist_comm {X : Type*} [MetricSpace X] (x y : X) : 
    dist x y = dist y x
axiom dist_triangle {X : Type*} [MetricSpace X] (x y z : X) : 
    dist x z ≤ dist x y + dist y z
```

### Metric Topology
```lean
-- Open ball
def Metric.ball {X : Type*} [MetricSpace X] (x : X) (r : ℝ) : Set X :=
  {y | dist y x < r}

-- Closed ball
def Metric.closedBall {X : Type*} [MetricSpace X] (x : X) (r : ℝ) : Set X :=
  {y | dist y x ≤ r}

-- Sphere
def Metric.sphere {X : Type*} [MetricSpace X] (x : X) (r : ℝ) : Set X :=
  {y | dist y x = r}

-- Metric space induces topology
instance {X : Type*} [MetricSpace X] : TopologicalSpace X :=
  MetricSpace.toTopologicalSpace
```

## Common Patterns

### Defining Topologies
```lean
-- Discrete topology (all sets open)
def discreteTopology (X : Type*) : TopologicalSpace X where
  IsOpen := fun _ => True
  isOpen_univ := trivial
  isOpen_inter := fun _ _ _ _ => trivial
  isOpen_sUnion := fun _ _ => trivial

-- Indiscrete topology (only ∅ and univ open)
def indiscreteTopology (X : Type*) : TopologicalSpace X where
  IsOpen := fun s => s = ∅ ∨ s = univ
  isOpen_univ := Or.inr rfl
  isOpen_inter := by
    intros s t hs ht
    cases hs <;> cases ht <;> simp [*]
  isOpen_sUnion := by
    intros s h
    by_cases h' : ∅ ∈ s
    · sorry  -- Complete proof
    · sorry  -- Complete proof
```

### Proving Continuity
```lean
-- Pattern: Prove function is continuous
example : Continuous (fun x : ℝ => x + 1) := by
  apply continuous_add
  · exact continuous_id
  · exact continuous_const

-- Using preimage characterization
example {f : ℝ → ℝ} (h : ∀ s, IsOpen s → IsOpen (f ⁻¹' s)) : 
    Continuous f := h
```

### Working with Neighborhoods
```lean
-- Show something is a neighborhood
example {X : Type*} [TopologicalSpace X] {s : Set X} {x : X} 
    (h : ∃ t, IsOpen t ∧ x ∈ t ∧ t ⊆ s) :
    s ∈ nhds x := by
  obtain ⟨t, ht_open, hx, hts⟩ := h
  exact mem_nhds_iff.mpr ⟨t, hts, ht_open, hx⟩
```

## Topological Properties

### Separation Axioms
```lean
-- T0 (Kolmogorov)
class T0Space (X : Type*) [TopologicalSpace X] : Prop where
  t0 : ∀ x y, x ≠ y → ∃ U, IsOpen U ∧ (x ∈ U ∧ y ∉ U ∨ y ∈ U ∧ x ∉ U)

-- T1 (Fréchet)
class T1Space (X : Type*) [TopologicalSpace X] : Prop where
  t1 : ∀ x, IsClosed ({x} : Set X)

-- T2 (Hausdorff)
class T2Space (X : Type*) [TopologicalSpace X] : Prop where
  t2 : ∀ x y, x ≠ y → ∃ U V, IsOpen U ∧ IsOpen V ∧ x ∈ U ∧ y ∈ V ∧ Disjoint U V

-- T3 (Regular)
class RegularSpace (X : Type*) [TopologicalSpace X] : Prop

-- T4 (Normal)
class NormalSpace (X : Type*) [TopologicalSpace X] : Prop
```

### Compactness
```lean
-- Compact space
class CompactSpace (X : Type*) [TopologicalSpace X] : Prop where
  isCompact_univ : IsCompact (univ : Set X)

-- Compact set
def IsCompact {X : Type*} [TopologicalSpace X] (s : Set X) : Prop :=
  ∀ {ι : Type*} (U : ι → Set X), (∀ i, IsOpen (U i)) → 
    s ⊆ ⋃ i, U i → ∃ t : Finset ι, s ⊆ ⋃ i ∈ t, U i

-- Heine-Borel theorem (for ℝⁿ)
theorem isCompact_iff_isClosed_bounded {s : Set ℝ} :
    IsCompact s ↔ IsClosed s ∧ IsBounded s
```

### Connectedness
```lean
-- Connected space
class ConnectedSpace (X : Type*) [TopologicalSpace X] : Prop where
  toPreconnectedSpace : PreconnectedSpace X
  toNonempty : Nonempty X

-- Connected set
def IsConnected {X : Type*} [TopologicalSpace X] (s : Set X) : Prop :=
  s.Nonempty ∧ IsPreconnected s

-- Path-connected
def IsPathConnected {X : Type*} [TopologicalSpace X] (s : Set X) : Prop :=
  s.Nonempty ∧ ∀ x ∈ s, ∀ y ∈ s, ∃ γ : Path x y, ∀ t, γ t ∈ s
```

## Mathlib Imports

### Basic Topology
```lean
import Mathlib.Topology.Basic               -- Core definitions
import Mathlib.Topology.Constructions       -- Product, sum topologies
import Mathlib.Topology.Separation          -- Separation axioms
import Mathlib.Topology.Connected           -- Connectedness
import Mathlib.Topology.Compactness.Compact -- Compactness
```

### Metric Spaces
```lean
import Mathlib.Topology.MetricSpace.Basic   -- Metric spaces
import Mathlib.Topology.MetricSpace.Bounded -- Bounded sets
import Mathlib.Topology.MetricSpace.Lipschitz -- Lipschitz functions
```

### Advanced Topics
```lean
import Mathlib.Topology.Homeomorph          -- Homeomorphisms
import Mathlib.Topology.ContinuousFunction.Basic -- Continuous functions
import Mathlib.Topology.UniformSpace.Basic  -- Uniform spaces
```

## Common Tactics

### For Topology Proofs
- `continuity` - Prove continuity automatically
- `simp [IsOpen, IsClosed]` - Simplify open/closed predicates
- `apply isOpen_sUnion` - Show union of opens is open
- `exact mem_nhds_iff.mpr` - Show neighborhood membership

### Examples
```lean
example : Continuous (fun x : ℝ => x^2 + 2*x + 1) := by
  continuity

example {X : Type*} [TopologicalSpace X] (s t : Set X) 
    (hs : IsOpen s) (ht : IsOpen t) :
    IsOpen (s ∪ t) := by
  apply isOpen_sUnion
  intro u hu
  cases hu <;> assumption
```

## Standard Examples

### Real Numbers
```lean
instance : TopologicalSpace ℝ := inferInstance
instance : MetricSpace ℝ := inferInstance
instance : T2Space ℝ := inferInstance
```

### Euclidean Space
```lean
import Mathlib.Analysis.NormedSpace.PiLp

instance {n : ℕ} : MetricSpace (EuclideanSpace ℝ (Fin n)) := 
  inferInstance
```

### Product Topology
```lean
instance {X Y : Type*} [TopologicalSpace X] [TopologicalSpace Y] :
    TopologicalSpace (X × Y) := inferInstance
```

## Business Rules

1. **Use filters for neighborhoods**: Don't manually work with neighborhood sets
2. **Prefer `continuity` tactic**: Automatic continuity proofs when possible
3. **Import metric space theory**: Don't redefine metric concepts
4. **Use bundled continuous functions**: `ContinuousMap X Y` for continuous maps
5. **Check separation axioms**: Many theorems require Hausdorff or stronger

## Common Pitfalls

1. **Confusing open and closed**: Remember complement relationship
2. **Forgetting Hausdorff**: Many results need T2 assumption
3. **Not using filters**: Manual neighborhood proofs are complex
4. **Missing metric space imports**: Metric theorems need explicit imports
5. **Ignoring compactness**: Many analysis results require compactness

## Relationships

- **Used by**: Analysis, differential geometry, algebraic topology
- **Related**: Uniform spaces, filters, convergence
- **Extends**: Set theory, order theory

## References

- Mathlib docs: `Mathlib.Topology`
- Mathematics in Lean: Chapter 11 (Topology)
- Topology textbooks (Munkres, Kelley)
