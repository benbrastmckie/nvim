# Dynamical Systems

## Overview

Dynamical systems study the evolution of systems over time. This file covers available formalizations and patterns for working with discrete and continuous dynamical systems in Lean 4.

## Core Definitions

### Discrete Dynamical System

A discrete dynamical system is defined by iterating a function.

```lean
import Mathlib.Dynamics.FixedPoints.Basic

-- Iteration of a function
def iterate {A : Type} (f : A -> A) : Nat -> A -> A
  | 0, x => x
  | n + 1, x => f (iterate f n x)

-- Orbit of a point
def orbit {A : Type} (f : A -> A) (x : A) : Set A :=
  {y | exists n : Nat, iterate f n x = y}

-- Forward orbit
def forwardOrbit {A : Type} (f : A -> A) (x : A) : Nat -> A :=
  fun n => iterate f n x
```

### Fixed Points

```lean
-- Fixed point
def IsFixedPt {A : Type} (f : A -> A) (x : A) : Prop :=
  f x = x

-- Periodic point
def IsPeriodicPt {A : Type} (f : A -> A) (n : Nat) (x : A) : Prop :=
  n > 0 and iterate f n x = x

-- Minimal period
def minimalPeriod {A : Type} (f : A -> A) (x : A) : Nat :=
  Nat.find (exists_pos_iterate_eq x)
```

### Continuous Dynamical System (Flow)

```lean
import Mathlib.Topology.ContinuousFunction.Basic

-- Flow on a topological space
structure Flow (X : Type) [TopologicalSpace X] where
  phi : Real -> X -> X
  phi_zero : forall x, phi 0 x = x
  phi_add : forall s t x, phi (s + t) x = phi t (phi s x)
  continuous_phi : Continuous (uncurry phi)

-- Trajectory
def trajectory {X : Type} [TopologicalSpace X]
    (flow : Flow X) (x : X) : Real -> X :=
  fun t => flow.phi t x
```

## Key Theorems

### Fixed Point Theorems

```lean
-- Banach fixed point theorem (contraction mapping)
theorem banach_fixedPoint {X : Type} [MetricSpace X] [CompleteSpace X]
    {f : X -> X} (k : Real) (hk : 0 <= k and k < 1)
    (hf : forall x y, dist (f x) (f y) <= k * dist x y) :
    exists! x, f x = x

-- Brouwer fixed point theorem
theorem brouwer_fixedPoint {n : Nat}
    {f : EuclideanSpace Real (Fin n) -> EuclideanSpace Real (Fin n)}
    (hf : Continuous f) :
    exists x in Metric.closedBall 0 1, f x = x
```

### Orbit Properties

```lean
-- Orbit is invariant under f
theorem orbit_invariant {A : Type} (f : A -> A) (x : A) :
    forall y in orbit f x, f y in orbit f x

-- Periodic points have finite orbits
theorem periodicPt_finite_orbit {A : Type} (f : A -> A) (x : A) (n : Nat)
    (h : IsPeriodicPt f n x) :
    (orbit f x).Finite
```

## Ergodic Theory

### Measure-Preserving Systems

```lean
import Mathlib.MeasureTheory.Measure.MeasureSpace

-- Measure-preserving transformation
def MeasurePreserving {X : Type} [MeasurableSpace X]
    (mu : Measure X) (f : X -> X) : Prop :=
  Measurable f and forall s, MeasurableSet s -> mu (f^(-1) s) = mu s

-- Ergodic transformation
def Ergodic {X : Type} [MeasurableSpace X]
    (mu : Measure X) (f : X -> X) : Prop :=
  MeasurePreserving mu f and
  forall s, MeasurableSet s -> f^(-1) s = s -> mu s = 0 or mu (compl s) = 0
```

## Common Patterns

### Defining Discrete Systems

```lean
-- Logistic map
def logisticMap (r : Real) : Real -> Real :=
  fun x => r * x * (1 - x)

-- Study fixed points
example (r : Real) : IsFixedPt (logisticMap r) 0 := by
  unfold IsFixedPt logisticMap
  ring
```

### Analyzing Orbits

```lean
-- Compute orbit
def computeOrbit {A : Type} (f : A -> A) (x : A) (n : Nat) : List A :=
  List.range n |>.map (fun k => iterate f k x)
```

## Standard Examples

### Logistic Map

```lean
def logisticMap (r : Real) (x : Real) : Real := r * x * (1 - x)
-- r < 1: fixed point at 0 is stable
-- 1 < r < 3: fixed point at (r-1)/r is stable
-- r > 3: period-doubling cascade
-- r ≈ 3.57: onset of chaos
```

### Tent Map

```lean
def tentMap (x : Real) : Real :=
  if x <= 1/2 then 2*x else 2*(1-x)
-- Chaotic for almost all initial conditions
```

### Circle Rotation

```lean
def circleRotation (alpha : Real) : Real -> Real :=
  fun x => (x + alpha) % 1
-- Ergodic if alpha is irrational
-- Periodic if alpha is rational
```

## Mathlib Imports

```lean
import Mathlib.Dynamics.FixedPoints.Basic
import Mathlib.Dynamics.PeriodicPts
import Mathlib.Dynamics.Ergodic.MeasurePreserving
import Mathlib.Topology.MetricSpace.Basic
import Mathlib.Analysis.ODE.PicardLindelof
```

## Applications

### Physics

- Hamiltonian systems
- Conservative systems
- Celestial mechanics

### Biology

- Population dynamics
- Predator-prey models
- Epidemic models

### Computer Science

- Iteration algorithms
- Chaos-based cryptography
- Random number generation

## References

- Devaney: An Introduction to Chaotic Dynamical Systems
- Strogatz: Nonlinear Dynamics and Chaos
- Mathlib Dynamics documentation
