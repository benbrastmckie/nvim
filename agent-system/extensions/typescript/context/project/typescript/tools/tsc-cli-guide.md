# `tsc` CLI Guide

Generic reference for the TypeScript compiler's command-line interface. Covers only `tsc`
itself — never a framework's own wrapper command (e.g. a framework CLI's own `check` subcommand),
which belongs in that framework's own extension.

## Type-Checking Without Emitting

```bash
tsc --noEmit
```

The standard "just tell me if this type-checks" invocation: runs the full type checker against
the project described by the nearest `tsconfig.json` but writes no output files. This is the
command this extension's verification hook runs when a project declares no more specific
typecheck script of its own (see `tools/package-manager-detection.md`).

## Watch Mode

```bash
tsc --noEmit --watch
```

Re-runs the check incrementally on every file save, reporting only what changed. Useful during
active development; never the right invocation for a one-shot CI/verification check, since it
does not exit.

## Project References: `--build`

```bash
tsc --build
tsc --build --force   # ignore .tsbuildinfo and rebuild everything
tsc --build --clean   # remove build output for the referenced projects
```

`--build` (`-b`) is the project-references-aware build mode: it builds each referenced project
in dependency order, skipping a project whose inputs have not changed since its last successful
build (tracked via a `.tsbuildinfo` file). Use this whenever `tsconfig.json` declares
`references` (see `domain/tsconfig-reference.md`) — a plain `tsc --noEmit` at the root does not
traverse references on its own.

## Useful One-Off Flags

| Flag | Purpose |
|------|---------|
| `--pretty` | Force colorized, formatted diagnostic output (useful when `tsc`'s own TTY detection is wrong, e.g. inside some CI log viewers) |
| `--listFiles` | Print every file the compiler considered part of the program — useful for debugging an unexpectedly large or small program |
| `--explainFiles` | Print *why* each file was included (which `import`/`include` pulled it in) |
| `--showConfig` | Print the fully-resolved effective config (after `extends` is applied) without running the compiler |
| `--incremental` | Write a `.tsbuildinfo` cache file to speed up a subsequent run, without requiring project references |

## Exit Codes

`tsc` exits `0` when the program contains no type errors (or, under `--noEmit`, no diagnostics
at all), and non-zero when it reports at least one error. A CI/verification step must check the
exit code directly — never infer pass/fail by scanning stdout for the absence of the word
"error", which misses a genuinely empty, successful run looking identical to a run whose output
was simply not captured.

## `isolatedModules`

When `tsconfig.json` sets `isolatedModules: true` (required for compatibility with most
single-file transpilers — esbuild, swc, Babel — which type-check nothing and transpile each
file independently), `tsc --noEmit` is still the right tool to actually catch type errors: the
transpiler itself performs no type checking at all, so `tsc` (or an editor's language-service
integration) is the only thing verifying types in that setup.
