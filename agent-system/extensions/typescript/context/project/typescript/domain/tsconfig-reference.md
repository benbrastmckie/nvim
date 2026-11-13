# `tsconfig.json` Reference

Generic `compilerOptions` reference for a `tsconfig.json`, the TypeScript compiler's own
configuration format. No framework presets are referenced here — a framework or host extension
(e.g. a web/browser extension) is the correct place for a preset that extends one of these
options for its own runtime target.

## Core `compilerOptions`

| Option | Purpose |
|--------|---------|
| `target` | The ECMAScript version the compiler emits (`ES2022`, `ESNext`, ...). Affects which language features are downleveled vs. emitted as-is. |
| `module` | The module output format (`CommonJS`, `ESNext`, `NodeNext`, ...). Must agree with how the code will actually be loaded at runtime — see `module-systems.md`. |
| `moduleResolution` | How module specifiers are resolved to files (`Node10`, `Node16`, `NodeNext`, `Bundler`). `NodeNext`/`Node16` enforce the same extension and `exports`-map rules Node itself applies. |
| `lib` | The set of built-in type declarations available (`["ES2022", "DOM"]`, etc.). Omit `DOM` entirely for a project that never runs in a browser-like environment. |
| `outDir` / `rootDir` | Where compiled output is written, and the root the compiler mirrors that structure from. |
| `declaration` | Emits a `.d.ts` file alongside each compiled module — required for a package meant to be consumed by other TypeScript code. |
| `sourceMap` | Emits `.map` files for debugging compiled output against original source. |
| `esModuleInterop` | Allows a default import of a CommonJS module that does not itself have a default export; nearly always wanted when interoperating with the npm ecosystem. |
| `skipLibCheck` | Skips type-checking of `.d.ts` files (including dependencies' own declaration files). Commonly enabled to avoid being blocked by a type error inside a third-party package's own types. |
| `resolveJsonModule` | Allows importing a `.json` file directly as a typed module. |
| `isolatedModules` | Requires every file to be independently transpilable without cross-file type information — required by most single-file transpilers (esbuild, swc, Babel); see `tools/tsc-cli-guide.md`. |

See `standards/typescript-style-guide.md`'s Strict-Mode Flags table for the `strict` family.

## Project References

For a multi-package repository (a monorepo, or a single repo with a clearly separated
library/app split), **project references** let `tsc` build each package independently and
incrementally, respecting declared dependency order:

```jsonc
// tsconfig.json at the repo root
{
  "files": [],
  "references": [
    { "path": "./packages/core" },
    { "path": "./packages/cli" }
  ]
}
```

Each referenced package's own `tsconfig.json` sets `"composite": true` (which implies
`declaration: true` and a few other constraints) so its build output can be consumed by a
project that references it. Build all referenced projects, in dependency order, with
`tsc --build` (see `tools/tsc-cli-guide.md`).

## Config Inheritance (`extends`)

A `tsconfig.json` may `extend` another config file, inheriting its `compilerOptions` and
overriding only what differs:

```jsonc
// tsconfig.base.json
{
  "compilerOptions": { "strict": true, "target": "ES2022" }
}

// packages/cli/tsconfig.json
{
  "extends": "../../tsconfig.base.json",
  "compilerOptions": { "outDir": "./dist" }
}
```

This is the generic mechanism a framework's own preset config (e.g. `some-framework/tsconfigs/strict`)
builds on; a project not using any such framework can define its own base config the same way.

## `include` / `exclude`

```jsonc
{
  "include": ["src/**/*"],
  "exclude": ["node_modules", "dist"]
}
```

`include`/`exclude` control which files the compiler considers part of the program when no
explicit `files` list is given. An empty `files: []` (as in the project-references example
above) combined with `references` is the conventional root-level shape for a multi-package
project, so the root config itself compiles nothing directly.
