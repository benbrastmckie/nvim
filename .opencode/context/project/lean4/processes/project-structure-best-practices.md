# LEAN 4 Project Structure Best Practices

## Overview
This file describes the recommended way to organize a LEAN 4 project to ensure maintainability and collaboration.

## When to Use
- When starting a new LEAN 4 project.
- When restructuring an existing LEAN 4 project.

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
- **`lean-toolchain`**: A file that specifies the version of LEAN 4 to use.
- **`MyProject/`**: The main source directory for the project.
- **`test/`**: The directory for tests.

## Business Rules
1. All source code should be placed in the `MyProject/` directory.
2. All tests should be placed in the `test/` directory.
3. The `lakefile.lean` file should be used to manage dependencies.

## Context Dependencies
- `mathlib-overview.md`

## Success Criteria
- The project is well-organized and easy to navigate.
- The project can be built and tested using `lake`.
