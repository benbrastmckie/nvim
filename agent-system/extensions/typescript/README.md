# TypeScript Extension

Generic, framework-agnostic TypeScript language, tooling, and configuration support: `tsconfig.json`
strictness and project references, module systems (ESM/CJS), runtime validation (Zod), and
`tsc`-based verification. Nothing in this extension's context tree references Astro, Vite,
React, Next.js, or Cloudflare — that content belongs to a framework-specific extension instead.

## Overview

| Task Type | Agent | Purpose |
|-----------|-------|---------|
| `typescript` | typescript-research-agent | TypeScript/tooling research |
| `typescript` | typescript-implementation-agent | TypeScript implementation |

## Installation

Loaded via the extension picker. Once loaded, `typescript` becomes a recognized task type.

## Commands

No dedicated commands. Use the core research, plan, and implement phases (dispatched via
`/orchestrate`) with `task_type: "typescript"`.

## Skill-Agent Mapping

| Skill | Agent | Purpose |
|-------|-------|---------|
| skill-typescript-research | typescript-research-agent | TypeScript/tooling research |
| skill-typescript-implementation | typescript-implementation-agent | TypeScript implementation |

## File Inventory

```
typescript/
  manifest.json                                          # Name, version, provides, routing, merge_targets, hard_contracts
  EXTENSION.md                                           # CLAUDE.md source content
  README.md                                              # This file
  index-entries.json                                     # Context index entries
  opencode-agents.json                                   # OpenCode agent definitions
  agents/typescript-research-agent.md                    # Research agent
  agents/typescript-implementation-agent.md              # Implementation agent (tsc verification loop)
  skills/skill-typescript-research/SKILL.md              # Thin wrapper skill
  skills/skill-typescript-implementation/SKILL.md        # Thin wrapper skill
  rules/typescript-rules.md                              # Auto-applied rule (*.ts, *.tsx, package.json, tsconfig*.json)
  scripts/typescript-verify.sh                           # verification-stage lifecycle hook
  context/contracts/typescript-adversarial-verification.md  # hard_contracts override (compiler-as-oracle)
  context/project/typescript/README.md                   # Generic context tree index
  context/project/typescript/standards/typescript-style-guide.md
  context/project/typescript/patterns/zod-validation-patterns.md
  context/project/typescript/patterns/path-alias-patterns.md
  context/project/typescript/domain/tsconfig-reference.md
  context/project/typescript/domain/module-systems.md
  context/project/typescript/tools/tsc-cli-guide.md
  context/project/typescript/tools/package-manager-detection.md
```

## Language Routing

| Task Type | Research Tools | Implementation Tools |
|-----------|----------------|---------------------|
| `typescript` | WebSearch, WebFetch, Read, Bash (read-shaped probes) | Read, Write, Edit, Bash (`tsc --noEmit`, package-manager scripts) |

## Verification

```bash
tsc --noEmit    # Full typecheck gate, run after each sub-step
```

The implementation agent runs `tsc --noEmit` (or the project's own declared typecheck command)
after each sub-step and blocks on failures. The `verification`-stage lifecycle hook
(`scripts/typescript-verify.sh`) additionally runs automatically after every dispatch's
artifacts are validated, reporting `ran_pass`/`ran_fail`/`skipped_no_command` per sub-check with
an honest-degrade guarantee: it never reports a pass when no typecheck or test command exists to
run.

## Deliberately Omitted

- **No `settings-fragment.json`**: nothing MCP- or permission-specific to configure for generic
  TypeScript work.
- **No `templates/`**: a generic TypeScript project has no fixed shape to scaffold, unlike a
  framework extension's page/component templates.
- **No `mcp-fragment.json`**: no TypeScript MCP server in wide use comparable to `mcp-nixos`.

## References

- [TypeScript Handbook](https://www.typescriptlang.org/docs/handbook/intro.html)
- [TypeScript release notes](https://www.typescriptlang.org/docs/handbook/release-notes/overview.html)
- [`@typescript-eslint` rules](https://typescript-eslint.io/rules/)
- [Zod documentation](https://zod.dev/)
