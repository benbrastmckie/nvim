# Path Alias Patterns

A generic, framework-agnostic convention for replacing deep relative imports
(`../../../../components/Card`) with a short, stable alias (`@components/Card`), defined once in
`tsconfig.json` and reused by every file in the project.

## Why Alias Imports

Deep relative paths are fragile: moving either the importing file or the imported file breaks
every relative reference between them, and the path itself carries no information about where
the imported module conceptually lives. An alias fixes both problems — it is stable under file
moves within the aliased directory, and it reads as a statement of module identity
(`@utils/dates`) rather than a filesystem accident.

## Defining Aliases in `tsconfig.json`

```jsonc
{
  "compilerOptions": {
    "baseUrl": ".",
    "paths": {
      "@utils/*": ["src/utils/*"],
      "@lib/*": ["src/lib/*"],
      "@types/*": ["src/types/*"]
    }
  }
}
```

`baseUrl` establishes the root that every `paths` entry is resolved relative to; `paths` maps an
alias prefix (ending in `/*` for a directory, or a bare name for a single module) to one or more
candidate real locations.

## Using an Alias

```typescript
// Instead of a deep relative path:
import { formatDate } from '../../../../utils/dates';

// Prefer the alias:
import { formatDate } from '@utils/dates';
```

## The Compiler Does Not Rewrite Paths at Runtime

`tsconfig.json` `paths` affects only how `tsc` and editor tooling resolve the import for
type-checking and navigation — it does not, by itself, change how the compiled JavaScript
resolves the import at runtime. Whatever actually executes the output (Node's module resolver, a
bundler, a test runner) needs its own, separately-configured alias resolution that mirrors the
`tsconfig.json` mapping, or the alias will type-check correctly but fail to resolve when run.
Concretely: Node's native ESM loader does not consult `tsconfig.json` `paths` at all; a Node
project relying on aliases needs either a loader/transform that does, or a build step that
rewrites aliased imports back to relative paths before the code reaches Node.

## Conventions

- Keep the alias set small and stable — each alias is effectively a public contract that every
  file in the project may depend on; renaming one later means touching every import that uses it.
- Prefer aliasing by directory (`@utils/*`) over aliasing individual files, so a new file dropped
  into an already-aliased directory is immediately importable without a `tsconfig.json` edit.
- Do not alias a path that is only ever imported from its own immediate siblings — a relative
  import (`./helper`) is clearer than an alias for a module with no cross-directory consumers.
