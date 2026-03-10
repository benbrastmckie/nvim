# Definition Template

## Overview

This template provides a structure for defining new mathematical objects in Lean 4.

## Template Structure

```lean
/--
This is a docstring for the definition.
-/
def myDefinition (arg1 : Type1) (arg2 : Type2) : ReturnType :=
  -- Definition body
  sorry
```

## Required Fields

- **`myDefinition`**: The name of the definition.
- **`arg1`, `arg2`**: The arguments to the definition.
- **`Type1`, `Type2`**: The types of the arguments.
- **`ReturnType`**: The return type of the definition.

## Best Practices

- Use this template for all new definitions.
- Write a clear and concise docstring.
- Fill in the `sorry` with the definition body.

## Examples

### Simple Definition

```lean
/-- The square of a natural number. -/
def square (n : Nat) : Nat :=
  n * n
```

### Dependent Definition

```lean
/-- A vector of length n with elements of type α. -/
def Vector (α : Type u) (n : Nat) : Type u :=
  Fin n → α
```

### Recursive Definition

```lean
/-- The length of a list. -/
def length {α : Type} : List α → Nat
  | [] => 0
  | _ :: xs => 1 + length xs
```

### Structure Definition

```lean
/-- A point in 2D space. -/
structure Point where
  x : Float
  y : Float
  deriving Repr
```
