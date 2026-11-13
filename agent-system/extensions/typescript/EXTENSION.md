## TypeScript Extension

This project includes generic TypeScript language, tooling, and configuration support via the
typescript extension. Framework- and host-agnostic: a task that is really about a specific
framework or hosting platform (component props typing, build/deploy tooling) is better served
by that framework's own extension (e.g. a web/browser extension) when one is loaded.

### Language Routing

| Language | Research Tools | Implementation Tools |
|----------|----------------|---------------------|
| `typescript` | WebSearch, WebFetch, Read, Bash (read-shaped probes: `tsc --version`, `npm ls`/`pnpm ls`, `jq`) | Read, Write, Edit, Bash (`tsc --noEmit`, the project's own package-manager scripts) |

### Skill-Agent Mapping

| Skill | Agent | Purpose |
|-------|-------|---------|
| skill-typescript-research | typescript-research-agent | TypeScript/tooling research |
| skill-typescript-implementation | typescript-implementation-agent | TypeScript implementation |

### Commands

No dedicated commands. Use the core research, plan, and implement phases (dispatched via
`/orchestrate`) with `task_type: "typescript"`.

### Verification

- Type-check: `tsc --noEmit` (or the project's own declared typecheck script)
- The `verification`-stage lifecycle hook (`scripts/typescript-verify.sh`) runs automatically
  after every `typescript` dispatch's artifacts are validated, detecting the project's package
  manager and typecheck/test commands and reporting `ran_pass`/`ran_fail`/`skipped_no_command`
  per sub-check — never a false pass when no command is configured.

### Context

- `context/project/typescript/README.md` - Generic TypeScript context tree index (style guide,
  `tsconfig.json`/module-system reference, Zod/path-alias patterns, `tsc`/package-manager tools)
