# TypeScript Context

Generic, framework-agnostic domain knowledge for TypeScript language, tooling, and
configuration tasks. Nothing under this directory references a specific runtime, bundler, or UI
framework — that content belongs in a framework-specific extension (e.g. a web/browser
extension) instead. This file is a pointer index only; it does not restate any subdirectory
file's content.

## Directory Structure

```
project/typescript/
├── README.md                              # This file
├── standards/
│   └── typescript-style-guide.md          # Naming, strict-mode flags, interface vs type,
│                                           #   type-only imports, unknown over any,
│                                           #   explicit return types
├── patterns/
│   ├── zod-validation-patterns.md         # Generic runtime-validation (Zod) vocabulary
│   └── path-alias-patterns.md             # tsconfig.json `paths` alias convention
├── domain/
│   ├── tsconfig-reference.md              # compilerOptions reference, project references,
│   │                                       #   config inheritance
│   └── module-systems.md                 # ESM vs CJS, package.json "type", exports map
└── tools/
    ├── tsc-cli-guide.md                   # tsc --noEmit / --watch / --build, exit codes
    └── package-manager-detection.md       # Lockfile-based npm/pnpm/yarn/bun detection
```

## Loading Strategy

**Always load first**: this README.

**Load for a style or naming question**: `standards/typescript-style-guide.md`.

**Load for a config question**: `domain/tsconfig-reference.md` for `compilerOptions` and
project references; `domain/module-systems.md` for ESM/CJS and `package.json` questions.

**Load for a validation question**: `patterns/zod-validation-patterns.md`.

**Load for an import-path question**: `patterns/path-alias-patterns.md`.

**Load for a command-line or detection question**: `tools/tsc-cli-guide.md` for running the
compiler; `tools/package-manager-detection.md` for determining which package manager and
scripts a project uses.

## Scope Boundary

This tree covers the TypeScript language, the `tsc` compiler, `tsconfig.json`, and
`package.json` module/script conventions only. A project that also uses a specific framework,
bundler, or hosting platform needs that framework's own extension (if one is loaded) for
framework-specific guidance (e.g. component props typing, route type inference, build/deploy
tooling specific to that framework) — this tree deliberately does not duplicate it.
