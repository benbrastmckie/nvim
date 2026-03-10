# New File Template

## Overview

This template provides a basic structure for new Lean 4 files.

## Template Structure

```lean
/-
Copyright (c) {year} {author}. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
Authors: {author}
-/

import Mathlib.Tactic

/-!
# {File Name}

This file defines...
-/

namespace {ProjectName}

-- Your code here

end {ProjectName}
```

## Required Fields

- **`{year}`**: The current year.
- **`{author}`**: The author's name.
- **`{File Name}`**: The name of the file.
- **`{ProjectName}`**: The name of the project.

## Best Practices

- Use this template for all new files.
- Fill in all the required fields.
- Keep the namespace consistent with the project structure.

## Example

```lean
/-
Copyright (c) 2026 Alice Smith. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
Authors: Alice Smith
-/

import Mathlib.Tactic

/-!
# Basic Definitions

This file defines the core data types and basic operations
for the theorem prover.
-/

namespace MyProject

/-- The main formula type. -/
inductive Formula where
  | atom : String → Formula
  | imp : Formula → Formula → Formula
  deriving Repr, DecidableEq

/-- Negation as a derived connective. -/
def Formula.neg (φ : Formula) : Formula :=
  Formula.imp φ (Formula.atom "false")

end MyProject
```
