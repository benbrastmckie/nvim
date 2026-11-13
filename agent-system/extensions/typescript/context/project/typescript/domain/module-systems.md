# Module Systems: ESM vs. CJS

Generic reference for the two module systems a TypeScript/Node project may target, and the
`package.json` fields that declare which one is in effect. This is the justification for this
extension's rules glob covering `package.json` alongside `.ts`/`.tsx` files: a module-system
mismatch is a configuration error, not a type error, so it is not caught by `tsc` alone.

## The Two Systems

- **CommonJS (CJS)**: `require()` / `module.exports`, Node's original module system. Resolution
  is synchronous; a CJS module can `require()` a CJS module at any point in its own execution.
- **ECMAScript Modules (ESM)**: `import` / `export`, the language-standard system. Resolution
  and top-level evaluation are asynchronous; imports are hoisted and statically analyzable.

## Declaring Which System Applies: `package.json` `"type"`

| `"type"` value | `.js` files are treated as | `.cjs` files are | `.mjs` files are |
|---|---|---|---|
| `"commonjs"` (default when `"type"` is absent) | CommonJS | CommonJS | ESM |
| `"module"` | ESM | CommonJS | ESM |

The `.cjs`/`.mjs` extensions are always unambiguous regardless of `"type"` — they exist
specifically so a single package can mix both systems when needed without relying on the
package-wide default.

## `tsconfig.json` `module` Must Agree

The compiler's `module` setting must match how the compiled output will actually be loaded:

- `"module": "NodeNext"` (or `"Node16"`) tells `tsc` to apply the *same* `package.json`
  `"type"`-driven and extension-driven rules Node itself applies, including requiring explicit
  file extensions in relative import specifiers under ESM (`import './util.js'`, not
  `import './util'`, even though the source file is `util.ts`).
- A mismatch between `tsconfig.json` `module` and the project's actual `package.json` `"type"`
  is a common source of "it type-checks but fails at runtime" bugs — see `tsconfig-reference.md`.

## The `exports` Map

`package.json`'s `"exports"` field is the modern way a package declares its public entry
points, and can declare different files for ESM vs. CJS consumers of the same package:

```jsonc
{
  "name": "my-lib",
  "type": "module",
  "exports": {
    ".": {
      "import": "./dist/index.mjs",
      "require": "./dist/index.cjs"
    }
  }
}
```

A package author shipping both formats ("dual publishing") must produce both build outputs and
must keep their respective type declarations (`.d.mts` / `.d.cts`, or a `"types"` condition
inside the same map) correctly paired with each — a `.d.ts` that does not match the module
system of the file it describes is a distinct failure mode from an ordinary type error.

## Interop Pitfalls

- A CJS module's `module.exports = foo` has no single clean ESM default-export equivalent in
  every case; `esModuleInterop` (see `tsconfig-reference.md`) smooths the common cases but does
  not change what is actually exported at runtime.
- Dynamic `import()` works in both systems and returns a Promise in both — prefer it over a
  conditional `require()` when a module must be loaded conditionally across both targets.
- Top-level `await` is valid only in ESM; a CJS module cannot use it at the top level of a file.
