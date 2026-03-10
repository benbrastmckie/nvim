# Lean 4 Project Structure Best Practices

## Overview

This file describes the recommended way to organize a Lean 4 project to ensure maintainability and collaboration.

## When to Use

- When starting a new Lean 4 project.
- When restructuring an existing Lean 4 project.

## Project Structure

```
.
├── lakefile.lean
├── lean-toolchain
├── MyProject
│   ├── Basic.lean
│   └── ...
└── test
    └── Basic.lean
```

- **`lakefile.lean`**: The build configuration file for the project.
- **`lean-toolchain`**: A file that specifies the version of Lean 4 to use.
- **`MyProject/`**: The main source directory for the project.
- **`test/`**: The directory for tests.

## Business Rules

1. All source code should be placed in the `MyProject/` directory.
2. All tests should be placed in the `test/` directory.
3. The `lakefile.lean` file should be used to manage dependencies.

## Directory Organization

### Module Hierarchy

Organize modules into logical namespaces:

```
MyProject/
├── Core/
│   ├── Basic.lean       -- Foundational definitions
│   └── Syntax.lean      -- Syntax definitions
├── Theorems/
│   ├── Soundness.lean   -- Soundness proofs
│   └── Completeness.lean -- Completeness proofs
└── Tactics/
    └── Custom.lean      -- Custom tactics
```

### Import Patterns

- Use transitive imports sparingly
- Create hub files that re-export common definitions
- Avoid circular imports

### lakefile.lean Configuration

```lean
import Lake
open Lake DSL

package myproject where
  leanOptions := #[
    ⟨`autoImplicit, false⟩,
    ⟨`pp.unicode.fun, true⟩
  ]

require mathlib from git
  "https://github.com/leanprover-community/mathlib4"

@[default_target]
lean_lib MyProject where
  roots := #[`MyProject]
```

## Context Dependencies

- `mathlib-overview.md`

## Success Criteria

- The project is well-organized and easy to navigate.
- The project can be built and tested using `lake`.
