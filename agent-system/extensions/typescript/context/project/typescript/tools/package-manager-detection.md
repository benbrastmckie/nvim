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

## No `package.json` At cwd, But One Exists Below

The verification-stage hook (`scripts/typescript-verify.sh`) is always invoked with cwd fixed at
the task's repo root, which is not necessarily where the Node/TypeScript project actually lives
(a project nested under a subdirectory, e.g. a monorepo package). When no `package.json` exists
directly at cwd, the hook runs a bounded, vendor-excluded fallback search below cwd before
concluding no project is in scope:

```
find . -maxdepth 4 -name package.json \
  -not -path '*/node_modules/*' -not -path '*/.git/*' -not -path '*/dist/*' \
  -not -path '*/build/*' -not -path '*/.next/*' -not -path '*/out/*' \
  -not -path '*/vendor/*' -not -path '*/.venv/*'
```

Results are sorted for determinism and verified in that order. At most 10 discovered projects
are verified (the cap); if more are found, a loud stderr `NOTICE` names the true count and
states the run is `INCOMPLETE` — a truncated run must never look like a complete one. Every
output line for a discovered (non-cwd) project is prefixed with that project's relative
directory, extending the hook's own `[typescript-verify]` tag rather than replacing it (e.g.
`[typescript-verify][packages/api] running test: npm run test`), and the three-state counters
(`ran_pass`, `ran_fail`, `skipped_no_command`) are aggregated across every verified project in
the final summary line.

A malformed `package.json` discovered this way does not abort the run: the hook prints an
`ERROR: ... -- skipping` line on stderr, counts one `skipped_no_command`, and continues to the
next discovered project. This is deliberately different from a malformed `package.json` found
directly at cwd (see "No Lockfile, But a `package.json` Exists" above and the hook's own
hook-input-error contract), which still exits the hook non-zero — one bad nested manifest must
never blank out findings for every sibling project, whereas a malformed manifest at the single
location the hook was explicitly pointed at is treated as a hook-input problem.

## No `package.json` At All

No Node/TypeScript project is in scope at this location — there is nothing to detect and
nothing to run. This is a normal, expected outcome for a non-Node TypeScript use case (a
standalone script invoked directly through `ts-node` or similar, or a project managed entirely
through a different ecosystem's tooling), not an error -- but only once the bounded fallback
search described above has ALSO come up empty. A `package.json` existing somewhere below cwd,
just outside the search's depth bound or beneath an excluded vendor/VCS directory, is a
different situation (deliberately not discovered, not "no project exists"), not the case this
section describes.

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
