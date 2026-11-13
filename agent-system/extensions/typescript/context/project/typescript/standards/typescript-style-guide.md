# TypeScript Style Guide

Generic naming, strictness, and type-authoring conventions for TypeScript code, independent of
any runtime, framework, or build tool.

## Naming Conventions

| Category | Convention | Example |
|----------|-----------|---------|
| Files | `kebab-case.ts` | `site-config.ts` |
| Directories | `kebab-case/` | `date-utils/` |
| Variables / functions | `camelCase` | `getUserData()` |
| Classes | `PascalCase` | `class UserRepository` |
| Interfaces / type aliases | `PascalCase` | `interface User`, `type Result<T>` |
| Enum members | `PascalCase` | `enum Status { Active, Archived }` |
| Constants (module-level, truly immutable) | `SCREAMING_SNAKE_CASE` | `const MAX_RETRIES = 3` |
| Type parameters | single uppercase letter, or a short `PascalCase` descriptive name | `T`, `TResult` |

## Strict-Mode Flags

Enable the full strict family in `tsconfig.json` — do not cherry-pick a subset. The umbrella
flag plus the flags it implies:

| Flag | Effect |
|------|--------|
| `strict` | Umbrella flag; enables every flag below |
| `noImplicitAny` | Disallows an inferred `any` with no explicit annotation |
| `strictNullChecks` | `null`/`undefined` are not assignable to other types unless explicitly unioned in |
| `strictFunctionTypes` | Function parameter types are checked contravariantly |
| `strictBindCallApply` | `bind`/`call`/`apply` are checked against the function's real signature |
| `strictPropertyInitialization` | A class property must be initialized in the constructor or declared possibly `undefined` |
| `noImplicitThis` | `this` must have an inferable or declared type |
| `alwaysStrict` | Emits `"use strict"` and parses in strict mode |

Additional flags worth enabling on a new project even though `strict` does not imply them:
`noUncheckedIndexedAccess` (an indexed access, `arr[i]`, is typed `T | undefined` rather than
`T`) and `noImplicitOverride` (an overriding method must be marked `override`).

## `interface` vs. `type`

- Prefer `interface` for object shapes that may need to be extended (`extends`) or that
  represent a public contract between modules — interfaces support declaration merging and
  produce clearer error messages when a shape mismatches.
- Prefer `type` for unions, intersections, tuples, mapped types, and conditional types —
  shapes `interface` cannot express at all.
- Do not mix the two arbitrarily for plain object shapes within one codebase; pick one default
  (interface) and reserve `type` for the cases `interface` cannot cover.

## Type-Only Imports

Use `import type { X } from '...'` (or the inline form, `import { type X, value } from '...'`)
whenever an imported name is used only in type positions. This is not merely stylistic:

- It guarantees the import is erased entirely from the compiled output, with no risk of a
  runtime import of a module that exists only for its types.
- Under `isolatedModules` (required by most single-file transpilers — see `tsc-cli-guide.md`),
  a type-only import that is not marked `import type` can produce an incorrect emit for the
  consuming tool, because that tool cannot see across files to know the import is type-only.

```typescript
import type { User } from './types';
import { createUser } from './factory';
```

## `unknown` Over `any`

`any` disables type checking entirely for every operation performed on the value — it is a type
system escape hatch, not a type. `unknown` is the type-safe counterpart: it accepts any value on
assignment but forbids every operation on it until the value has been narrowed (via a type
guard, an `instanceof` check, or a runtime validator — see `zod-validation-patterns.md`).

```typescript
function handle(input: unknown) {
  if (typeof input === 'string') {
    return input.toUpperCase(); // narrowed to string
  }
  throw new Error('unexpected input shape');
}
```

Treat a new `any` in a code review the same as a new `@ts-ignore`: it must be justified in a
comment naming why no typed alternative was available, not left unexplained.

## Explicit Return Types

Declare an explicit return type on every exported function and every function whose inferred
return type is not immediately obvious from its body. This is not about distrust of inference —
it is about keeping the function's public contract stable: a change to the function body that
accidentally widens or narrows the inferred return type is caught immediately as a type error at
every call site, rather than silently propagating.

```typescript
export function parseConfig(raw: string): Config {
  // ...
}
```
