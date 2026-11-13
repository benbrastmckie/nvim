---
paths: ["**/*.ts", "**/*.tsx", "package.json", "tsconfig*.json"]
---

# TypeScript Development Rules

## Path Pattern

Applies to: `**/*.ts`, `**/*.tsx`, `package.json`, `tsconfig*.json`. Repo-root-relative by
design: a generic TypeScript extension cannot assume any particular source-root convention
(`src/`, `lib/`, a flat repo root, or a monorepo package layout). `tsconfig*.json` is a glob
rather than a literal filename so it covers `tsconfig.json`, `tsconfig.base.json`,
`tsconfig.build.json`, and project-reference variants alike.

## Coding Standards

### Indentation
- Use 2 spaces for indentation
- Never use tabs
- Maximum line length: 100 characters

### Naming Conventions

| Category | Convention | Example |
|----------|-----------|---------|
| Files | `kebab-case.ts` | `site-config.ts` |
| Directories | `kebab-case/` | `date-utils/` |
| Classes | `PascalCase` | `class UserRepository` |
| TypeScript files | `kebab-case.ts` | `site-config.ts` |
| Variables/functions | `camelCase` | `getUserData()` |
| Interfaces/Types | `PascalCase` | `interface User` |
| Constants | `SCREAMING_SNAKE_CASE` | `MAX_RETRIES` |

## TypeScript Standards

| Rule | Description |
|------|-------------|
| No `any` | Use `unknown` + type guards instead |
| Explicit return types | Functions must declare return types |
| `interface` over `type` | Prefer `interface` for object shapes (extendable) |
| Type-only imports | Use `import type { X }` for type-only imports |
| Nullish coalescing | Use `??` over logical OR for defaults |
| Optional chaining | Use `?.` for nullable access |
| Strict mode | `tsconfig.json` must enable the full `strict` family, not a cherry-picked subset |

See `@.claude/context/project/typescript/standards/typescript-style-guide.md` for the full
rationale behind each rule above.

## Module and Configuration Conventions

| Rule | Description |
|------|-------------|
| `package.json` `"type"` | Must agree with `tsconfig.json`'s `module` setting — see `@.claude/context/project/typescript/domain/module-systems.md` |
| Path aliases | Define in `tsconfig.json` `paths`, never a deep relative import chain — see `@.claude/context/project/typescript/patterns/path-alias-patterns.md` |
| Runtime validation | Validate any value crossing a runtime boundary (config, API response, env var) with a schema (e.g. Zod) rather than an unchecked type assertion — see `@.claude/context/project/typescript/patterns/zod-validation-patterns.md` |

## Verification

```bash
# Type-check without emitting
tsc --noEmit

# Project-references build
tsc --build
```

A CI/verification step must check the exit code directly — never infer pass/fail from scanning
stdout for the absence of the word "error". See
`@.claude/context/project/typescript/tools/tsc-cli-guide.md`.

## Do Not

- Use `any` type (use `unknown` + type guards)
- Introduce an `as`-cast, `@ts-expect-error`, or `@ts-ignore` without naming, in the surrounding
  comment or commit, why no typed alternative was available
- Use `||` for defaults where `??` is appropriate
- Parse an untrusted or loosely-typed runtime value with an unchecked type assertion
  (`JSON.parse(...) as T`) instead of a runtime validator
- Change `tsconfig.json`'s `module`/`moduleResolution` or `package.json`'s `"type"` without
  re-running a full `tsc --noEmit` across the whole program afterward
- Cherry-pick individual strict-family flags instead of enabling `strict` as a whole

## Related Context

Load for detailed patterns:
- `@.claude/context/project/typescript/README.md`
- `@.claude/context/project/typescript/standards/typescript-style-guide.md`
- `@.claude/context/project/typescript/domain/tsconfig-reference.md`
- `@.claude/context/project/typescript/domain/module-systems.md`
- `@.claude/context/project/typescript/patterns/zod-validation-patterns.md`
- `@.claude/context/project/typescript/patterns/path-alias-patterns.md`
- `@.claude/context/project/typescript/tools/tsc-cli-guide.md`
- `@.claude/context/project/typescript/tools/package-manager-detection.md`
