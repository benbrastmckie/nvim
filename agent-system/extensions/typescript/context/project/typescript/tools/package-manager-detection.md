# Package Manager Detection

Generic, lockfile-based detection of which Node package manager a project uses — the
human-readable companion to the same logic the `verification`-stage hook script
(`scripts/typescript-verify.sh`) implements mechanically.

## Detection by Lockfile

| Lockfile present | Package manager |
|---|---|
| `pnpm-lock.yaml` | pnpm |
| `yarn.lock` | yarn |
| `package-lock.json` | npm |
| `bun.lockb` | bun |

Check in this priority order and stop at the first match. A project should commit exactly one
lockfile; if more than one is present, the earliest-matching one in this table wins, but this
situation itself is worth flagging to the project's maintainers — mixed lockfiles mean different
contributors have been installing with different tools, which can silently diverge dependency
resolution between them.

## No Lockfile, But a `package.json` Exists

Default to npm. Every package manager in the table above can read and run an npm-style
`package.json` `scripts` map; npm is the only one guaranteed to already be present wherever
Node itself is installed, with no separate install step of its own.

## No `package.json` At All

No Node/TypeScript project is in scope at this location — there is nothing to detect and
nothing to run. This is a normal, expected outcome for a non-Node TypeScript use case (a
standalone script invoked directly through `ts-node` or similar, or a project managed entirely
through a different ecosystem's tooling), not an error.

## Running a Script Once the Package Manager Is Known

| Package manager | Run a `package.json` script named `foo` |
|---|---|
| npm | `npm run foo` |
| pnpm | `pnpm run foo` (or `pnpm foo`) |
| yarn | `yarn foo` |
| bun | `bun run foo` |

## Detecting a Declared Script

Read `package.json`'s `.scripts` map (`jq -r '.scripts // {}'`) and look for a conventional
name, checked in priority order: `typecheck`, `type-check`, `tsc`, `check`. The first one
present is the project's own declared typecheck entry point and should always be preferred over
a bare `tsc --noEmit` fallback, because the project's own script may pass additional flags,
check multiple project references, or run against a non-default config file the bare fallback
would miss.

## Rejecting npm's Placeholder Test Script

A freshly-scaffolded `package.json` commonly ships:

```json
{ "scripts": { "test": "echo \"Error: no test specified\" && exit 1" } }
```

Treat this exact placeholder (or any `test` script whose body is recognizably the unmodified
npm-init default) as equivalent to no test script being declared at all — running it produces a
failing exit code that reports nothing real about the project, which is a false-fail rather than
a true one, and reporting it as "tests failed" would be as misleading as a false pass.
